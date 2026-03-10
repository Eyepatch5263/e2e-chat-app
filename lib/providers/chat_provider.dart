import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/chat_service.dart';

/// Exposes ChatService state to the widget tree via Provider.
class ChatProvider extends ChangeNotifier {
  final ChatService _svc = ChatService();
  bool _connected = false;

  StreamSubscription? _msgSub;
  StreamSubscription? _sessSub;
  StreamSubscription? _connSub;

  bool              get isConnected => _connected;
  List<ChatSession> get sessions    => _svc.sessions;

  Future<void> initialize() async {
    await _svc.initialize();
    _msgSub  = _svc.onMessage.listen((_) => notifyListeners());
    _sessSub = _svc.onSessionUpdate.listen((_) => notifyListeners());
    _connSub = _svc.onConnectionChange.listen((c) {
      _connected = c;
      notifyListeners();
    });
  }

  List<ChatMessage> getMessages(String peerId) => _svc.getMessages(peerId);

  Future<ChatSession?> startSession({
    required String peerId,
    required String peerUsername,
  }) async {
    try {
      final s = await _svc.startSession(
          peerId: peerId, peerUsername: peerUsername);
      notifyListeners();
      return s;
    } catch (e) {
      print('[ChatProvider] startSession failed: $e');
      return null;
    }
  }

  Future<void> sendMessage({
    required String peerId,
    required String plaintext,
    Duration? selfDestructDuration,
  }) async {
    await _svc.sendMessage(
      peerId:                peerId,
      plaintext:             plaintext,
      selfDestructDuration:  selfDestructDuration,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _sessSub?.cancel();
    _connSub?.cancel();
    _svc.dispose();
    super.dispose();
  }
}
