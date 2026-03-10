/// Delivery / lifecycle status of a chat message.
enum MessageStatus { sending, sent, delivered, failed, expired }

/// A single chat message.
///
/// [content]    – decrypted plaintext (never leaves the device).
/// [ciphertext] – encrypted payload (transmitted over the wire).
class ChatMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final String? ciphertext;
  final int ratchetCounter;
  final DateTime timestamp;
  final DateTime? expiresAt;
  MessageStatus status;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    this.ciphertext,
    required this.ratchetCounter,
    required this.timestamp,
    this.expiresAt,
    this.status = MessageStatus.sending,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Duration? get remainingTime {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
