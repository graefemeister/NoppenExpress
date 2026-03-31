package de.graefemeister.NoppenExpress

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.noppenexpress/ble_native"
    private var advertiser: BluetoothLeAdvertiser? = null
    private var lastPayload: ByteArray? = null
    
    private val advertiseCallback = object : android.bluetooth.le.AdvertiseCallback() {
        override fun onStartFailure(errorCode: Int) {
            Log.e("BLE_NATIVE", "Advertising fehlgeschlagen: Error $errorCode")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        advertiser = bluetoothAdapter?.bluetoothLeAdvertiser

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startDinoAdvertising") {
                val payload = call.argument<ByteArray>("payload")
                if (payload != null) {
                    sendBleAdvertisement(payload)
                    result.success(true)
                } else {
                    result.error("NULL_PAYLOAD", "Payload war leer", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun sendBleAdvertisement(payload: ByteArray) {
        // Dubletten-Check: Nur senden, wenn sich etwas geändert hat
        if (lastPayload?.contentEquals(payload) == true) return
        lastPayload = payload

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .build()

        val data = AdvertiseData.Builder()
            .addManufacturerData(0x00FF, payload)
            .setIncludeDeviceName(false)
            .build()

        try {
            advertiser?.stopAdvertising(advertiseCallback)
            advertiser?.startAdvertising(settings, data, advertiseCallback)
            Log.d("BLE_NATIVE", "Sende: ${payload.joinToString("") { "%02x ".format(it) }}")
        } catch (e: Exception) {
            Log.e("BLE_NATIVE", "Hardware-Fehler: ${e.message}")
        }
    }
}