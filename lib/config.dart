/// Server configuration.
///
/// For **production** set your deployed URL before building:
///   flutter build apk --dart-define=SERVER_URL=https://your-server.onrender.com
///
/// For **development** it defaults to the Android-emulator loopback.
class AppConfig {
  // Compile-time override via --dart-define=SERVER_URL=...
  static const String _override =
      String.fromEnvironment('SERVER_URL', defaultValue: '');

  /// When no override is given we fall back to the emulator loopback.
  static const String _devHost = '10.0.2.2';
  static const int _devPort = 3000;

  // ── derived URLs ────────────────────────────────────────────────────

  static String get httpBaseUrl {
    if (_override.isNotEmpty) {
      // Strip trailing slash if present
      final base = _override.endsWith('/')
          ? _override.substring(0, _override.length - 1)
          : _override;
      return base;
    }
    return 'http://$_devHost:$_devPort';
  }

  static String get wsUrl {
    if (_override.isNotEmpty) {
      final base = _override.endsWith('/')
          ? _override.substring(0, _override.length - 1)
          : _override;
      // https → wss, http → ws
      final wsBase = base.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
      return '$wsBase/connect';
    }
    return 'ws://$_devHost:$_devPort/connect';
  }

  /// Default self-destruct timer for ephemeral messages.
  static const Duration defaultMessageExpiry = Duration(minutes: 5);
}
