import 'package:flutter/material.dart';

/// Chat input bar with self-destruct toggle and send button.
class ChatInput extends StatefulWidget {
  final void Function(String text, bool selfDestruct) onSend;

  const ChatInput({super.key, required this.onSend});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _ctrl = TextEditingController();
  bool _selfDestruct = false;

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text, _selfDestruct);
    _ctrl.clear();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(children: [
          // Self-destruct toggle
          IconButton(
            icon: Icon(
              _selfDestruct ? Icons.timer : Icons.timer_outlined,
              color: _selfDestruct ? cs.error : Colors.grey,
            ),
            tooltip: _selfDestruct
                ? 'Self-destruct ON'
                : 'Enable self-destruct',
            onPressed: () => setState(() => _selfDestruct = !_selfDestruct),
          ),
          // Text field
          Expanded(
            child: TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: _selfDestruct
                    ? 'Self-destruct message\u2026'
                    : 'Encrypted message\u2026',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          CircleAvatar(
            backgroundColor: cs.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _send,
            ),
          ),
        ]),
      ),
    );
  }
}
