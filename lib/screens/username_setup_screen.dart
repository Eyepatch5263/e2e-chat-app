import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Username registration screen shown after key generation.
class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});
  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    final name = _ctrl.text.trim();
    if (name.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final auth = context.read<AuthProvider>();
    final ok = await auth.registerUsername(name);

    if (!ok && mounted) {
      setState(() {
        _loading = false;
        // Show the actual error from AuthProvider / ApiClient
        _error = auth.lastError ?? 'Registration failed – check server connection';
      });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.person_add_outlined, size: 64, color: cs.primary),
              const SizedBox(height: 24),
              Text('Choose your username',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Your identity keys have been generated.\n'
                'Choose a username so others can find you.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  errorText: _error,
                  errorMaxLines: 3,
                ),
                onSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 16),
              Card(
                color: cs.primary.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(Icons.lock, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your private keys never leave this device. '
                        'Only public keys are shared with the server.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.primary),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _register,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create Account',
                        style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
