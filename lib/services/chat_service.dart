import 'dart:async';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../network/api.dart';
import '../network/websocket_service.dart';
import '../storage/secure_storage.dart';
import '../storage/session_store.dart';
import '../config.dart';
import 'crypto_service.dart';

// ---------------------------------------------------------------------------
// ChatService – orchestrates encrypted messaging
// ---------------------------------------------------------------------------
//
// Call hierarchy enforced by architecture:
//   Widget → Provider → ChatService → CryptoService → crypto/*
//
// This service:
//   • Manages WebSocket lifecycle.
//   • Stores / loads sessions via SessionStore.
//   • Delegates ALL crypto to CryptoService (never imports crypto/ directly).
//   • Publishes message & session streams for the UI layer.
// ---------------------------------------------------------------------------

class ChatService {
  final WebSocketService _ws = WebSocketService();
  final Map<String, ChatSession>       _sessions = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, String>            _pendingEK = {}; // ephemeral keys

  final _msgNotify  = StreamController<ChatMessage>.broadcast();
  final _sessNotify = StreamController<ChatSession>.broadcast();

  Stream<ChatMessage> get onMessage        => _msgNotify.stream;
  Stream<ChatSession> get onSessionUpdate  => _sessNotify.stream;
  Stream<bool>        get onConnectionChange => _ws.connectionStream;
  bool                get isConnected      => _ws.isConnected;

  StreamSubscription<Map<String, dynamic>>? _wsSub;

  String? _userId;

  // ── Lifecycle ───────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _userId = await SecureStorage.getUserId();
    if (_userId == null) return;
    _sessions.addAll(await SessionStore.loadSessions());
    await _ws.connect(_userId!);
    await _wsSub?.cancel();
    _wsSub = _ws.messageStream.listen(_onWsMessage);
  }

  List<ChatSession> get sessions {
    final list = _sessions.values.toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return list;
  }

  List<ChatMessage> getMessages(String peerId) {
    _purgeExpired(peerId);
    return _messages[peerId] ?? [];
  }

  // ── Start a new session (X3DH initiator) ────────────────────────────────

  Future<ChatSession?> startSession({
    required String peerId,
    required String peerUsername,
  }) async {
    if (_sessions.containsKey(peerId)) return _sessions[peerId];

    final bundle = await ApiClient.fetchKeyBundle(peerId);
    if (bundle == null) throw Exception('Could not fetch peer key bundle');

    final result = await CryptoService.initiateHandshake(bundle);

    final session = ChatSession(
      peerId: peerId,
      peerUsername: peerUsername,
      chainKey: result.chainKey,
    );
    _sessions[peerId] = session;
    await SessionStore.saveSession(session);
    _sessNotify.add(session);

    _pendingEK[peerId] = result.ephemeralPublicKey;
    return session;
  }

  // ── Send an encrypted message ───────────────────────────────────────────

  Future<ChatMessage?> sendMessage({
    required String peerId,
    required String plaintext,
    bool selfDestruct = false,
  }) async {
    final session = _sessions[peerId];
    if (session == null || _userId == null) return null;

    final enc = await CryptoService.encryptMessage(
      plaintext:   plaintext,
      chainKey:    session.chainKey,
      senderId:    _userId!,
      recipientId: peerId,
    );

    // Ratchet forward – old chain key is gone (forward secrecy).
    session.chainKey = enc.nextChainKey;
    session.sendCounter++;
    session.lastActivity = DateTime.now();
    session.lastMessage  = plaintext;
    await SessionStore.saveSession(session);

    final expiresAt = selfDestruct
        ? DateTime.now().add(AppConfig.defaultMessageExpiry)
        : null;

    final msg = ChatMessage(
      id:             DateTime.now().millisecondsSinceEpoch.toString(),
      senderId:       _userId!,
      recipientId:    peerId,
      content:        plaintext,
      ciphertext:     enc.ciphertext,
      ratchetCounter: session.sendCounter,
      timestamp:      DateTime.now(),
      expiresAt:      expiresAt,
      status:         MessageStatus.sending,
    );

    _messages.putIfAbsent(peerId, () => []);
    _messages[peerId]!.add(msg);

    _ws.sendMessage(
      recipientId:    peerId,
      ciphertext:     enc.ciphertext,
      ratchetCounter: session.sendCounter,
      ephemeralKey:   _pendingEK.remove(peerId),
      expiresAt:      expiresAt,
    );

    msg.status = MessageStatus.sent;
    _msgNotify.add(msg);
    _sessNotify.add(session);
    return msg;
  }

  // ── Incoming WebSocket frames ───────────────────────────────────────────

  Future<void> _onWsMessage(Map<String, dynamic> data) async {
    switch (data['type']) {
      case 'chat_message':
        await _handleChat(data);
      case 'delivery_ack':
        _handleAck(data);
    }
  }

  Future<void> _handleChat(Map<String, dynamic> data) async {
    final senderId = data['sender_id'] as String;
    final ct       = data['ciphertext'] as String;
    final counter  = (data['ratchet_counter'] ?? 0) as int;
    final ek       = data['ephemeral_key'] as String?;
    final expStr   = data['expires_at'] as String?;

    // If no session exists, perform responder-side X3DH.
    if (!_sessions.containsKey(senderId)) {
      if (ek == null) return; // cannot establish session without EK
      final bundle = await ApiClient.fetchKeyBundle(senderId);
      if (bundle == null) return;

      final chainKey = await CryptoService.respondToHandshake(
        peerIdentityDhPublicB64: bundle.identityDhPublicKey,
        peerEphemeralPublicB64:  ek,
      );

      _sessions[senderId] = ChatSession(
        peerId:       senderId,
        peerUsername:  bundle.identityPublicKey.substring(0, 8),
        chainKey:     chainKey,
      );
      await SessionStore.saveSession(_sessions[senderId]!);
    }

    final session = _sessions[senderId]!;

    try {
      final dec = await CryptoService.decryptMessage(
        ciphertext:  ct,
        chainKey:    session.chainKey,
        senderId:    senderId,
        recipientId: _userId!,
      );

      session.chainKey = dec.nextChainKey;
      session.receiveCounter++;
      session.lastActivity = DateTime.now();
      session.lastMessage  = dec.plaintext;
      await SessionStore.saveSession(session);

      final msg = ChatMessage(
        id:             DateTime.now().millisecondsSinceEpoch.toString(),
        senderId:       senderId,
        recipientId:    _userId!,
        content:        dec.plaintext,
        ratchetCounter: counter,
        timestamp:      DateTime.now(),
        expiresAt:      expStr != null ? DateTime.parse(expStr) : null,
        status:         MessageStatus.delivered,
      );

      _messages.putIfAbsent(senderId, () => []);
      _messages[senderId]!.add(msg);
      _msgNotify.add(msg);
      _sessNotify.add(session);
    } catch (e) {
      print('[ChatService] decryption failed: $e');
    }
  }

  void _handleAck(Map<String, dynamic> data) {
    // Could update individual message status here.
    print('[ChatService] delivery ack: ${data['status']}');
  }

  void _purgeExpired(String peerId) {
    _messages[peerId]?.removeWhere((m) => m.isExpired);
  }

  void dispose() {
    _wsSub?.cancel();
    _ws.dispose();
    _msgNotify.close();
    _sessNotify.close();
  }
}