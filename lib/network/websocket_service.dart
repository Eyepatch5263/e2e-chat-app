import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

// ---------------------------------------------------------------------------
// WebSocket service – real-time encrypted message relay
// ---------------------------------------------------------------------------
//
// Protocol (all payloads are JSON):
//   1. Client connects to  ws://host:port/connect
//   2. Sends  { type: "auth", user_id }
//   3. Server replies { type: "welcome" }
//   4. Bidirectional chat_message frames (encrypted client-side).
//
// The server is a dumb pipe – it forwards ciphertext blobs without
// inspecting or storing them.
// ---------------------------------------------------------------------------

class WebSocketService {
  WebSocketChannel? _channel;
  final _msgCtrl  = StreamController<Map<String, dynamic>>.broadcast();
  final _connCtrl = StreamController<bool>.broadcast();
  bool   _connected = false;
  String? _userId;

  Stream<Map<String, dynamic>> get messageStream   => _msgCtrl.stream;
  Stream<bool>                 get connectionStream => _connCtrl.stream;
  bool                         get isConnected      => _connected;

  /// Connect and authenticate with the relay server.
  Future<void> connect(String userId) async {
    _userId = userId;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));

      _channel!.stream.listen(
        (raw) {
          try {
            final data = json.decode(raw as String) as Map<String, dynamic>;
            _onData(data);
          } catch (_) {}
        },
        onError: (_) { _setConnected(false); _reconnectLater(); },
        onDone:  ()  { _setConnected(false); _reconnectLater(); },
      );

      _send({'type': 'auth', 'user_id': userId});
    } catch (_) {
      _setConnected(false);
      _reconnectLater();
    }
  }

  void _onData(Map<String, dynamic> data) {
    if (data['type'] == 'welcome') {
      _setConnected(true);
    } else {
      _msgCtrl.add(data);
    }
  }

  /// Send an encrypted chat message through the relay.
  void sendMessage({
    required String recipientId,
    required String ciphertext,
    required int    ratchetCounter,
    String?   ephemeralKey,
    DateTime? expiresAt,
  }) {
    _send({
      'type':            'chat_message',
      'recipient_id':    recipientId,
      'ciphertext':      ciphertext,
      'ratchet_counter': ratchetCounter,
      'ephemeral_key':   ephemeralKey,
      'timestamp':       DateTime.now().toIso8601String(),
      'expires_at':      expiresAt?.toIso8601String(),
    });
  }

  // ── internal ────────────────────────────────────────────────────────────

  void _send(Map<String, dynamic> data) =>
      _channel?.sink.add(json.encode(data));

  void _setConnected(bool v) {
    _connected = v;
    _connCtrl.add(v);
  }

  Timer? _reconnTimer;
  void _reconnectLater() {
    _reconnTimer?.cancel();
    _reconnTimer = Timer(const Duration(seconds: 5), () {
      if (_userId != null && !_connected) connect(_userId!);
    });
  }

  void disconnect() {
    _reconnTimer?.cancel();
    _channel?.sink.close();
    _setConnected(false);
  }

  void dispose() {
    _reconnTimer?.cancel();
    _channel?.sink.close();
    _msgCtrl.close();
    _connCtrl.close();
  }
}
