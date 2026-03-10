
/// Represents an active encrypted session with a peer.
///
/// The [chainKey] is the current ratchet state – it MUST be overwritten
/// after every send/receive and the old value securely discarded.
class ChatSession {
  final String peerId;
  final String peerUsername;
  String chainKey;       // current chain key (base64) – mutated on every msg
  int sendCounter;
  int receiveCounter;
  DateTime lastActivity;
  String? lastMessage;   // plaintext preview for chat list

  ChatSession({
    required this.peerId,
    required this.peerUsername,
    required this.chainKey,
    this.sendCounter = 0,
    this.receiveCounter = 0,
    DateTime? lastActivity,
    this.lastMessage,
  }) : lastActivity = lastActivity ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'peer_username': peerUsername,
        'chain_key': chainKey,
        'send_counter': sendCounter,
        'receive_counter': receiveCounter,
        'last_activity': lastActivity.toIso8601String(),
        'last_message': lastMessage,
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      peerId: json['peer_id'] as String,
      peerUsername: json['peer_username'] as String,
      chainKey: json['chain_key'] as String,
      sendCounter: (json['send_counter'] ?? 0) as int,
      receiveCounter: (json['receive_counter'] ?? 0) as int,
      lastActivity: DateTime.parse(json['last_activity'] as String),
      lastMessage: json['last_message'] as String?,
    );
  }
}
