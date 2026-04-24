package de.graefemeister.NoppenExpress // <-- Prüfe, ob das dein Paketname ist!

import android.bluetooth.le.*
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.noppenexpress/ble_native"
    
    private var advertiser: BluetoothLeAdvertiser? = null
    private val activeSets = mutableMapOf<Int, AdvertisingSet>()
    private val activeCallbacks = mutableMapOf<Int, AdvertisingSetCallback>()
    private val lastPayloads = mutableMapOf<Int, ByteArray>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Bluetooth Advertiser initialisieren
        val adapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
        advertiser = adapter?.bluetoothLeAdvertiser

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMouldKingBroadcast" -> {
                    val payload = call.argument<ByteArray>("payload")
                    val companyId = call.argument<Int>("companyId") ?: 0x4B4D

                    if (payload != null) {
                        // 1. HARD RESET (wie in den MK+ Logs: broadcast_stop)
                        // Das löscht das alte Set und erzwingt eine neue MAC-Adresse
                        stopEverything()

                        // 2. Die Parameter (Sicher & Kraftvoll)
                        val parameters = AdvertisingSetParameters.Builder()
                            .setLegacyMode(true)
                            .setConnectable(true) // Zurück auf True (Hub braucht das!)
                            .setScannable(true)
                            .setInterval(AdvertisingSetParameters.INTERVAL_MIN)
                            .setTxPowerLevel(AdvertisingSetParameters.TX_POWER_HIGH)
                            .build()

                        val data = AdvertiseData.Builder()
                            .addManufacturerData(companyId, payload)
                            .build()

                        // 3. Callback & Start
                        val callback = object : AdvertisingSetCallback() {
                            override fun onAdvertisingSetStarted(set: AdvertisingSet?, txPower: Int, status: Int) {
                                if (status == 0 && set != null) {
                                    activeSets[companyId] = set
                                }
                            }
                        }

                        activeCallbacks[companyId] = callback
                        
                        // 4. DER BLITZ: Wir senden für 20ms (duration = 2)
                        // Das ist stabil genug für ein Paket, aber kurz genug für die Rotation
                        advertiser?.startAdvertisingSet(parameters, data, null, null, null, 2, 0, callback)
                        
                        result.success(true)
                    } else {
                        result.error("NULL", "Payload leer", null)
                    }
                }
                "stopMouldKingBroadcast" -> {
                    stopEverything()
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun stopEverything() {
        activeCallbacks.forEach { (id, callback) ->
            try {
                advertiser?.stopAdvertisingSet(callback)
            } catch (e: Exception) {
                Log.e("BLE", "Fehler beim Stoppen von $id")
            }
        }
        activeSets.clear()
        activeCallbacks.clear()
        lastPayloads.clear()
    }
}