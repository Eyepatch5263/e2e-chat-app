import 'package:app/screens/security_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/username_setup_screen.dart';
import 'screens/chat_list_screen.dart';
import 'package:flutter/services.dart';

class UsbService {
  static const MethodChannel _channel = MethodChannel('usb_detection');

  static Future<Map?> getUsbDevices() async {
    final result = await _channel.invokeMethod('getUsbDevices');
    return result;
  }
}

void checkUSB() async {
  var devices = await UsbService.getUsbDevices();
  print(devices);
}

/// Root widget – routes to the correct screen based on auth state.
class SecureChatApp extends StatefulWidget {
  const SecureChatApp({super.key});

  @override
  State<SecureChatApp> createState() => _SecureChatAppState();
}

class _SecureChatAppState extends State<SecureChatApp> {
  @override
  void initState() {
    super.initState();
    checkUSB();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureChat',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light, // force light for Women's Day theme
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFE91E63), // Women's Day pink
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF0F3), // soft blush bg
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFCE4EC), // pink-50
          foregroundColor: Color(0xFF880E4F), // pink-900
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFE91E63),
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xFFF48FB1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xFFF48FB1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xFFE91E63), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E63),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFFE91E63),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          switch (auth.state) {
            case AuthState.loading:
            case AuthState.needsSetup:
              return const SplashScreen();
            case AuthState.needsUsername:
              return const UsernameSetupScreen();
            case AuthState.authenticated:
              return const SecurityCheckScreen();
          }
        },
      ),
    );
  }
}
