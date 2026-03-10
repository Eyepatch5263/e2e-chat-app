import 'package:flutter/material.dart';

/// Chat input bar with self-destruct duration picker and send button.
class ChatInput extends StatefulWidget {
  final void Function(String text, Duration? selfDestructDuration) onSend;

  const ChatInput({super.key, required this.onSend});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _ctrl = TextEditingController();

  // null = off, otherwise the selected duration
  static const List<_TimerOption> _options = [
    _TimerOption(null, 'Off'),
    _TimerOption(Duration(seconds: 15), '15s'),
    _TimerOption(Duration(seconds: 30), '30s'),
    _TimerOption(Duration(minutes: 1), '1m'),
  ];

  int _selectedIndex = 0;
  Duration? get _selfDestructDuration => _options[_selectedIndex].duration;

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text, _selfDestructDuration);
    _ctrl.clear();
  }

  void _cycleTimer() {
    setState(() {
      _selectedIndex = (_selectedIndex + 1) % _options.length;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = _selfDestructDuration != null;

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
          // Self-destruct timer picker — tap to cycle through options
          GestureDetector(
            onTap: _cycleTimer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? cs.error.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? Icons.timer : Icons.timer_outlined,
                    size: 20,
                    color: active ? cs.error : Colors.grey,
                  ),
                  if (active) ...[
                    const SizedBox(width: 4),
                    Text(
                      _options[_selectedIndex].label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Text field
          Expanded(
            child: TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: active
                    ? 'Disappears in ${_options[_selectedIndex].label}\u2026'
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

class _TimerOption {
  final Duration? duration;
  final String label;
  const _TimerOption(this.duration, this.label);
}
