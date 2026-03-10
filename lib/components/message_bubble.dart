import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';

/// Encrypted message bubble with delivery status, self-destruct timer,
/// and an encrypted-indicator lock icon.
class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  Timer? _timer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    if (widget.message.expiresAt != null) {
      _tick();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _remaining = widget.message.remainingTime);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isExpired) return _expired(context);

    final cs = Theme.of(context).colorScheme;
    final mine = widget.isMe;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .75),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              widget.message.content,
              style: TextStyle(
                color: mine ? Colors.white : cs.onSurface,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔒 encrypted indicator
                Icon(Icons.lock, size: 10,
                    color: mine ? Colors.white70 : Colors.grey),
                const SizedBox(width: 4),
                // timestamp
                Text(_hhmm(widget.message.timestamp),
                    style: TextStyle(
                        fontSize: 11,
                        color: mine ? Colors.white70 : Colors.grey)),
                // self-destruct countdown
                if (_remaining != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.timer, size: 11,
                      color: mine ? Colors.white70 : Colors.orange),
                  const SizedBox(width: 2),
                  Text(_dur(_remaining!),
                      style: TextStyle(
                          fontSize: 11,
                          color: mine ? Colors.white70 : Colors.orange)),
                ],
                // delivery indicator
                if (mine) ...[const SizedBox(width: 4), _status()],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _expired(BuildContext context) => Align(
        alignment:
            widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.timer_off, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text('Message expired',
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                    fontSize: 13)),
          ]),
        ),
      );

  Widget _status() {
    switch (widget.message.status) {
      case MessageStatus.sending:
        return const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: Colors.white70));
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.white70);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline,
            size: 14, color: Colors.redAccent);
      case MessageStatus.expired:
        return const Icon(Icons.timer_off, size: 14, color: Colors.white70);
    }
  }

  String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _dur(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }
}
