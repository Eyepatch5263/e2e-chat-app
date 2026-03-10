import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../network/api.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

/// Search for users by username and start an encrypted session.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<UserModel> _results = [];
  bool _searching = false;

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    _results = await ApiClient.searchUsers(q);
    setState(() => _searching = false);
  }

  Future<void> _startChat(UserModel user) async {
    final chat = context.read<ChatProvider>();
    final auth = context.read<AuthProvider>();

    // Don't chat with yourself
    if (user.userId == auth.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot chat with yourself')));
      return;
    }

    final session = await chat.startSession(
        peerId: user.userId, peerUsername: user.username);

    if (session != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
              peerId: user.userId, peerUsername: user.username),
        ),
      );
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Users')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: 'Search by username\u2026',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search),
            ),
            onSubmitted: (_) => _search(),
          ),
        ),
        if (_searching) const LinearProgressIndicator(),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text('Search for users to start a secure chat',
                      style: TextStyle(color: Colors.grey.shade500)))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final user = _results[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user.username[0].toUpperCase()),
                      ),
                      title: Text(user.username),
                      subtitle: Text(
                          'ID: ${user.userId.substring(0, 12)}\u2026',
                          style: const TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.chat_bubble_outline),
                      onTap: () => _startChat(user),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
