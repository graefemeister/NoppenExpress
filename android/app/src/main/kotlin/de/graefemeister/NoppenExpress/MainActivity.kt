package de.graefemeister.NoppenExpress

import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.*
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.noppenexpress/ble_native"
    private var advertiser: BluetoothLeAdvertiser? = null
    
    // Speicher für die aktiven Verbindungen pro Hub-ID
    private val activeSets = mutableMapOf<Int, AdvertisingSet?>()
    private val activeCallbacks = mutableMapOf<Int, AdvertisingSetCallback>()
    private val lastPayloads = mutableMapOf<Int, ByteArray>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val adapter = BluetoothAdapter.getDefaultAdapter()
        advertiser = adapter?.bluetoothLeAdvertiser

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDinoAdvertising" -> {
                    val payload = call.argument<ByteArray>("payload")
                    val companyId = call.argument<Int>("companyId") ?: 0x00FF
                    val connectable = call.argument<Boolean>("connectable") ?: true 
                    val scannable = call.argument<Boolean>("scannable") ?: true

                    if (payload != null) {
                        // Namen für die Lok ("MOULD KING") setzen
                        if (companyId == 0x4B4D && adapter?.name != "MOULD KING") {
                            try { adapter?.name = "MOULD KING" } catch (e: Exception) {}
                        }
                        
                        updateHub(payload, companyId, connectable, scannable)
                        result.success(true)
                    } else {
                        result.error("NULL", "Payload leer", null)
                    }
                }
                "stopDinoAdvertising" -> {
                    stopEverything()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun updateHub(payload: ByteArray, companyId: Int, connectable: Boolean, scannable: Boolean) {
        // Falls exakt dieser Funkspruch schon läuft und die Daten gleich sind -> nichts tun
        if (activeSets[companyId] != null && lastPayloads[companyId]?.contentEquals(payload) == true) return
        
        lastPayloads[companyId] = payload

        // Wenn der Broadcaster für diesen Hub schon läuft, tauschen wir nur die Daten aus
        val currentSet = activeSets[companyId]
        if (currentSet != null) {
            try {
                val data = AdvertiseData.Builder()
                    .addManufacturerData(companyId, payload)
                    .setIncludeDeviceName(false)
                    .build()
                currentSet.setAdvertisingData(data)
                return
            } catch (e: Exception) {
                Log.e("BLE_NATIVE", "Update fehlgeschlagen für 0x${Integer.toHexString(companyId)}, starte neu...")
                stopHub(companyId)
            }
        }

        // Neue Konfiguration starten
        val parameters = AdvertisingSetParameters.Builder()
            .setLegacyMode(true)
            .setConnectable(connectable)
            .setScannable(scannable)
            .setInterval(if (companyId == 0x4B4D) AdvertisingSetParameters.INTERVAL_MIN else AdvertisingSetParameters.INTERVAL_MEDIUM)
            .setTxPowerLevel(AdvertisingSetParameters.TX_POWER_HIGH)
            .build()

        val data = AdvertiseData.Builder()
            .addManufacturerData(companyId, payload)
            .setIncludeDeviceName(false)
            .build()

        val scanResponse = if (scannable) {
            AdvertiseData.Builder().setIncludeDeviceName(true).build()
        } else null

        val callback = object : AdvertisingSetCallback() {
            override fun onAdvertisingSetStarted(set: AdvertisingSet?, txPower: Int, status: Int) {
                if (status == 0) {
                    activeSets[companyId] = set
                    Log.d("BLE_NATIVE", "Hub 0x${Integer.toHexString(companyId)} bereit")
                } else {
                    Log.e("BLE_NATIVE", "Start Fehler 0x${Integer.toHexString(companyId)}: $status")
                    activeSets.remove(companyId)
                }
            }
        }

        activeCallbacks[companyId] = callback
        advertiser?.startAdvertisingSet(parameters, data, scanResponse, null, null, callback)
    }

    private fun stopHub(id: Int) {
        try {
            activeSets[id]?.let { advertiser?.stopAdvertisingSet(activeCallbacks[id]) }
        } catch (e: Exception) {}
        activeSets.remove(id)
        activeCallbacks.remove(id)
        lastPayloads.remove(id)
    }

    private fun stopEverything() {
        activeSets.keys.toList().forEach { stopHub(it) }
        Log.d("BLE_NATIVE", "Alle Hubs gestoppt")
    }
}