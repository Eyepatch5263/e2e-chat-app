import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// List of all active encrypted chat sessions.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.shield_outlined, size: 22),
          SizedBox(width: 8),
          Text('SecureChat'),
        ]),
        actions: [
          // Connection indicator
          Consumer<ChatProvider>(
            builder: (_, chat, __) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                chat.isConnected ? Icons.cloud_done : Icons.cloud_off,
                color: chat.isConnected ? const Color(0xFFE91E63) : Colors.red,
                size: 20,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (_, chat, __) {
          final sessions = chat.sessions;
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No conversations yet',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('Search for users to start an encrypted chat',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade400)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (_, i) {
              final s = sessions[i];
              return ListTile(
                leading: CircleAvatar(
                    child: Text(s.peerUsername[0].toUpperCase())),
                title: Text(s.peerUsername,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Row(children: [
                  const Icon(Icons.lock, size: 11, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      s.lastMessage ?? 'Encrypted session',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ]),
                trailing: Text(
                  _relative(s.lastActivity),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                        peerId: s.peerId, peerUsername: s.peerUsername),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SearchScreen())),
        child: const Icon(Icons.chat_outlined),
      ),
    );
  }

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
