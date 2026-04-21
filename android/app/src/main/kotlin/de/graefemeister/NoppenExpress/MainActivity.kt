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
                    // Falls keine ID mitkommt, gehen wir vom Classic-Hub aus
                    val companyId = call.argument<Int>("companyId") ?: 0x4B4D

                    if (payload != null) {
                        // HIER WIRD DAS PROFIL ERKANNT
                        val isRwy = (companyId == 0xFFF0)

                        // ----------------------------------------------------
                        // REGEL 1: Die Flags (Scan Response)
                        // RWY braucht zwingend die "02 01 02" Flags im Funk.
                        // Classic Hubs ignorieren das oder verschlucken sich daran.
                        // ----------------------------------------------------
                        val scanResponse = if (isRwy) {
                            AdvertiseData.Builder().setIncludeDeviceName(false).build()
                        } else null

                        // ----------------------------------------------------
                        // REGEL 2: Die Scannable-Eigenschaft
                        // Android erlaubt eine ScanResponse nur, wenn das Paket "scannable" ist.
                        // ----------------------------------------------------
                        val parameters = AdvertisingSetParameters.Builder()
                            .setLegacyMode(true)
                            .setConnectable(true)
                            .setScannable(isRwy) // Nur bei RWY auf true!
                            .setInterval(AdvertisingSetParameters.INTERVAL_MIN)
                            .setTxPowerLevel(AdvertisingSetParameters.TX_POWER_HIGH)
                            .build()

                        val data = AdvertiseData.Builder()
                            .addManufacturerData(companyId, payload)
                            .setIncludeDeviceName(false)
                            .build()

                        val callback = object : AdvertisingSetCallback() {
                            override fun onAdvertisingSetStarted(set: AdvertisingSet?, txPower: Int, status: Int) {
                                if (status == 0 && set != null) {
                                    activeSets[companyId] = set
                                }
                            }
                        }

                        activeCallbacks[companyId] = callback
                        
                        // ----------------------------------------------------
                        // REGEL 3: Die Blitz-Dauer (Duration)
                        // RWY-Pakete sind doppelt so lang (31 Bytes) wie Classic-Pakete.
                        // Sie brauchen länger in der Luft (50ms statt 20ms).
                        // ----------------------------------------------------
                        val duration = if (isRwy) 5 else 2 

                        advertiser?.startAdvertisingSet(parameters, data, scanResponse, null, null, duration, 0, callback)
                        
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