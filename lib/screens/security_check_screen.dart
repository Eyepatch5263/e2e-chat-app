import 'package:app/screens/chat_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class UsbService {
  static const MethodChannel _channel = MethodChannel('usb_detection');

  static Future<Map?> getUsbDevices() async {
    final result = await _channel.invokeMethod('getUsbDevices');
    return result;
  }
}

class SecurityCheckScreen extends StatefulWidget {
  const SecurityCheckScreen({super.key});

  @override
  State<SecurityCheckScreen> createState() => _SecurityCheckScreenState();
}

class _SecurityCheckScreenState extends State<SecurityCheckScreen> {

  bool authorized = false;

  @override
  void initState() {
    super.initState();
    verifyDevice();
  }

  Future<void> verifyDevice() async {

    var devices = await UsbService.getUsbDevices();

    if (devices != null && devices.isNotEmpty) {

      for (var d in devices.values) {

        if (d["vendorId"] == 1921 &&
            d["productId"] == 21683) {

          setState(() {
            authorized = true;
          });

          return;
        }
      }
    }

    setState(() {
      authorized = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    if (authorized) {
      return const ChatListScreen();
    }

    return Scaffold(
      body: Center(
        child: Text(
          "Unauthorized Device\nInsert authorized USB",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}