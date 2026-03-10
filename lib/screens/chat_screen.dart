import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../components/message_bubble.dart';
import '../components/chat_input.dart';

/// Individual encrypted chat screen.
class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerUsername;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollCtrl = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            child: Text(widget.peerUsername[0].toUpperCase(),
                style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.peerUsername, style: const TextStyle(fontSize: 16)),
              Row(children: [
                const Icon(Icons.lock, size: 10, color: Color(0xFFE91E63)),
                const SizedBox(width: 4),
                Text('End-to-end encrypted',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ]),
            ],
          ),
        ]),
      ),
      body: Column(children: [
        // Security banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: Color(0xFFFCE4EC),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 12, color: Color(0xFFC2185B)),
              const SizedBox(width: 6),
              Text(
                'Messages are end-to-end encrypted with forward secrecy',
                style: TextStyle(fontSize: 11, color: Color(0xFFC2185B)),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (_, chat, __) {
              final msgs = chat.getMessages(widget.peerId);
              _scrollToBottom();
              if (msgs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Send the first encrypted message',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: msgs.length,
                itemBuilder: (_, i) => MessageBubble(
                  message: msgs[i],
                  isMe: msgs[i].senderId == userId,
                ),
              );
            },
          ),
        ),
        // Input bar
        ChatInput(
          onSend: (text, selfDestructDuration) {
            context.read<ChatProvider>().sendMessage(
                  peerId: widget.peerId,
                  plaintext: text,
                  selfDestructDuration: selfDestructDuration,
                );
          },
        ),
      ]),
    );
  }
}
