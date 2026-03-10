import 'dart:async';
import 'package:app/screens/chat_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../storage/secure_storage.dart';
import '../storage/session_store.dart';

class UsbService {
  static const MethodChannel _channel = MethodChannel('usb_detection');
  static const EventChannel _eventChannel = EventChannel('usb_events');

  static Future<List?> getUsbDevices() async {
    try {
      final result = await _channel.invokeMethod('getUsbDevices');
      return result;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getDeviceId() async {
    try {
      final result = await _channel.invokeMethod('getDeviceId');
      return result as String?;
    } catch (e) {
      return null;
    }
  }

  /// Stream of USB attach/detach events.
  /// Each event is a Map with: action ("attached"/"detached"), vendorId, productId
  static Stream<Map<dynamic, dynamic>> get usbEventStream =>
      _eventChannel.receiveBroadcastStream().map((e) => e as Map<dynamic, dynamic>);
}

class SecurityCheckScreen extends StatefulWidget {
  const SecurityCheckScreen({super.key});

  @override
  State<SecurityCheckScreen> createState() => _SecurityCheckScreenState();
}

class _SecurityCheckScreenState extends State<SecurityCheckScreen> {
  static const String _authorizedDeviceId = '82e39642b17935cb';
  static const int _usbVendorId = 1921;
  static const int _usbProductId = 21863;

  bool authorized = false;
  String _reason = '';
  bool _resetting = false;

  StreamSubscription? _usbSub;

  @override
  void initState() {
    super.initState();
    verifyDevice();
    _listenUsbEvents();
  }

  @override
  void dispose() {
    _usbSub?.cancel();
    super.dispose();
  }

  void _listenUsbEvents() {
    _usbSub = UsbService.usbEventStream.listen((event) {
      final action = event['action'] as String?;
      final vendorId = event['vendorId'] as int?;
      final productId = event['productId'] as int?;

      if (action == 'detached' &&
          vendorId == _usbVendorId &&
          productId == _usbProductId) {
        // Authorized USB was removed — wipe account
        _resetAccount();
      } else if (action == 'attached' &&
          vendorId == _usbVendorId &&
          productId == _usbProductId) {
        // USB re-inserted — re-verify
        verifyDevice();
      }
    });
  }

  Future<void> _resetAccount() async {
    if (_resetting) return;
    _resetting = true;

    // 1. Disconnect WebSocket and wipe in-memory sessions/messages
    context.read<ChatProvider>().reset();

    // 2. Wipe all persistent keys, sessions, and messages
    await SecureStorage.clearAll();
    await SessionStore.clearAll();

    if (mounted) {
      // 3. Pop all routes back to root so ChatScreen can't stay open
      Navigator.of(context).popUntil((route) => route.isFirst);

      // 4. Reset auth state — triggers rebuild to splash/setup
      await context.read<AuthProvider>().initialize();
    }
  }

  Future<void> verifyDevice() async {
    final deviceId = await UsbService.getDeviceId();

    if (_authorizedDeviceId.isNotEmpty) {
      if (deviceId == null || deviceId != _authorizedDeviceId) {
        setState(() {
          authorized = false;
          _reason = 'Unauthorized phone';
        });
        return;
      }
    }

    final devices = await UsbService.getUsbDevices();

    if (devices != null && devices.isNotEmpty) {
      for (var d in devices) {
        if (d["vendorId"] == _usbVendorId && d["productId"] == _usbProductId) {
          setState(() {
            authorized = true;
          });
          return;
        }
      }
    }

    setState(() {
      authorized = false;
      _reason = 'Insert authorized USB';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (authorized) {
      return const ChatListScreen();
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                'Unauthorized Access',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                _reason,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              
            ],
          ),
        ),
      ),
    );
  }
}
