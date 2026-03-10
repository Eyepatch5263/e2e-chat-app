import 'package:app/screens/chat_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UsbService {
  static const MethodChannel _channel = MethodChannel('usb_detection');

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
}

class SecurityCheckScreen extends StatefulWidget {
  const SecurityCheckScreen({super.key});

  @override
  State<SecurityCheckScreen> createState() => _SecurityCheckScreenState();
}

class _SecurityCheckScreenState extends State<SecurityCheckScreen> {
  // ── Set your authorised phone's ANDROID_ID here ──
  // Leave empty to skip the phone check (USB-only mode).
  // Run the app once with it empty — the screen will show your device ID.
  static const String _authorizedDeviceId = '82e39642b17935cb';

  bool authorized = false;
  String _reason = '';

  @override
  void initState() {
    super.initState();
    verifyDevice();
  }

  Future<void> verifyDevice() async {
    // 1. Get device ID
    final deviceId = await UsbService.getDeviceId();

    // 2. If a device ID is configured, check it first
    if (_authorizedDeviceId.isNotEmpty) {
      if (deviceId == null || deviceId != _authorizedDeviceId) {
        setState(() {
          authorized = false;
          _reason = 'Unauthorized phone';
        });
        return;
      }
    }

    // 3. Check USB
    final devices = await UsbService.getUsbDevices();

    if (devices != null && devices.isNotEmpty) {
      for (var d in devices) {
        if (d["vendorId"] == 1921 && d["productId"] == 21863) {
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
              // Show device ID so you can copy it for configuration
              // if (_deviceId != null) ...[
              //   const SizedBox(height: 32),
              //   const Divider(),
              //   const SizedBox(height: 8),
              //   const Text('Your Device ID:',
              //       style: TextStyle(fontSize: 12, color: Colors.grey)),
              //   const SizedBox(height: 4),
              //   SelectableText(
              //     _deviceId!,
              //     style: const TextStyle(
              //       fontSize: 14,
              //       fontFamily: 'monospace',
              //       fontWeight: FontWeight.bold,
              //     ),
              //   ),
              //   const SizedBox(height: 8),
              //   // Text(
              //   //   'Copy this ID and set it as\n_authorizedDeviceId in security_check_screen.dart',
              //   //   textAlign: TextAlign.center,
              //   //   style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              //   // ),
              // ],
              // const SizedBox(height: 32),
              // ElevatedButton.icon(
              //   onPressed: verifyDevice,
              //   icon: const Icon(Icons.refresh),
              //   label: const Text('Retry'),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
