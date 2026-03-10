package com.pratyush.securechat

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.provider.Settings
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Block screenshots and screen recording on all screens
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
    }

    private val CHANNEL = "usb_detection"
    private val EVENT_CHANNEL = "usb_events"

    private var usbReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── MethodChannel (request/response) ──────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getUsbDevices" -> {
                        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
                        val deviceList = usbManager.deviceList
                        val devices = mutableListOf<Map<String, Any>>()
                        for (device in deviceList.values) {
                            devices.add(mapOf(
                                "vendorId" to device.vendorId,
                                "productId" to device.productId,
                                "deviceName" to device.deviceName
                            ))
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

        // ── EventChannel (USB attach/detach stream) ───────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    usbReceiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            val device = intent?.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                            val eventData = mapOf(
                                "action" to when (intent?.action) {
                                    UsbManager.ACTION_USB_DEVICE_DETACHED -> "detached"
                                    UsbManager.ACTION_USB_DEVICE_ATTACHED -> "attached"
                                    else -> "unknown"
                                },
                                "vendorId" to (device?.vendorId ?: 0),
                                "productId" to (device?.productId ?: 0)
                            )
                            events?.success(eventData)
                        }
                    }
                    val filter = IntentFilter().apply {
                        addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
                        addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
                    }
                    registerReceiver(usbReceiver, filter)
                }

                override fun onCancel(arguments: Any?) {
                    usbReceiver?.let { unregisterReceiver(it) }
                    usbReceiver = null
                }
            })
    }

    override fun onDestroy() {
        usbReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        super.onDestroy()
    }
}
