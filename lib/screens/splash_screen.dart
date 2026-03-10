import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Splash screen – generates identity keys on first launch.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Initializing secure environment\u2026';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    await auth.initialize();

    if (auth.state == AuthState.needsSetup) {
      setState(() => _status = 'Generating identity keys\u2026');
      await auth.generateKeys();
      setState(() => _status = 'Keys generated securely \u2713');
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_outlined, size: 64, color: cs.primary),
            ),
            const SizedBox(height: 32),
            Text('SecureChat',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 8),
            Text('End-to-End Encrypted',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey)),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
