package com.pratyush.securechat

import android.hardware.usb.UsbManager
import android.content.Context
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val CHANNEL = "usb_detection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {
                    "getUsbDevices" -> {
                        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
                        val deviceList = usbManager.deviceList

                        val devices = mutableListOf<Map<String, Any>>()

                        for (device in deviceList.values) {
                            val deviceInfo = mapOf(
                                "vendorId" to device.vendorId,
                                "productId" to device.productId,
                                "deviceName" to device.deviceName
                            )
                            devices.add(deviceInfo)
                        }

                        result.success(devices)
                    }

                    "getDeviceId" -> {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        result.success(androidId)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
