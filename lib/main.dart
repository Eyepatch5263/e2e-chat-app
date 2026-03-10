import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'app.dart';


/// Entry point.
///
/// Registers the two top-level ChangeNotifierProviders:
///   • [AuthProvider]  – identity key lifecycle & registration state.
///   • [ChatProvider]  – encrypted messaging, sessions, WebSocket.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const SecureChatApp(),
    ),
  );
}
