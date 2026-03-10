import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../storage/secure_storage.dart';
import '../storage/session_store.dart';

/// Settings screen – displays identity info and allows account reset.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Identity card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.fingerprint, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('Identity',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const Divider(),
                  _row('Username', auth.username ?? 'Unknown'),
                  const SizedBox(height: 8),
                  _row('User ID',
                      '${auth.userId?.substring(0, 16) ?? '?'}\u2026'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Security info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.shield_outlined, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('Security',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const Divider(),
                  _infoTile(Icons.lock, 'End-to-end encryption',
                      'XChaCha20-Poly1305 AEAD'),
                  _infoTile(Icons.swap_horiz, 'Key agreement',
                      'X3DH with X25519 + Ed25519'),
                  _infoTile(Icons.autorenew, 'Forward secrecy',
                      'HMAC-SHA256 chain-key ratchet'),
                  _infoTile(Icons.storage, 'Key storage',
                      'Platform secure storage'),
                  _infoTile(Icons.cloud_off, 'Server',
                      'Zero-knowledge relay (no message storage)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Danger zone
          OutlinedButton.icon(
            onPressed: () => _confirmReset(context),
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text('Reset Account',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      );

  Widget _infoTile(IconData icon, String title, String subtitle) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13)),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
      );

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Account?'),
        content: const Text(
            'This will delete all keys, sessions, and messages. '
            'You will need to re-register.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await SecureStorage.clearAll();
              await SessionStore.clearAll();
              if (context.mounted) {
                Navigator.pop(context);
                // Force restart
                await context.read<AuthProvider>().initialize();
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
