import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'dart:convert';                                 
import 'train_controller.dart';

class MouldKingController extends TrainController {
  MouldKingController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    device = BluetoothDevice.fromId(config.mac);

    device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && isRunning) {
        isRunning = false;
        onStatusChanged?.call();
      }
    });

    await device!.connect(); 
    await Future.delayed(const Duration(milliseconds: 500));
    
    List<BluetoothService> services = await device!.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString().toLowerCase().contains("ae3b")) {
          writeCharacteristic = characteristic;
        }
      }
    }

    if (writeCharacteristic != null) {
      List<String> wakeupCmds = ["T041AABBW", "T00EW", "T01F1W", "T00CW"];
      for (var cmd in wakeupCmds) {
        await writeCharacteristic!.write(utf8.encode(cmd), withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      isRunning = true;
      onStatusChanged?.call();
      senderLoop();
    }
  }

  String _pctToHex(double pct) {
    if (pct == 0) return "0000";
    int val = (pct.abs() / 100.0 * 32767).toInt();
    if (pct < 0) val += 0x8000;
    return val.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  // --- DIE HARDWARE-METHODE DER BASISKLASSE ---
  @override
  void sendHardwareCommand() {
    // BLE Flood Protection:
    // Da Mould King einen 100ms Heartbeat braucht, überlassen wir das Senden
    // komplett der senderLoop(). Wenn wir hier bei jedem Ramping-Schritt (z.B. alle 10ms)
    // funken würden, könnte der Bluetooth-Chip überlastet werden.
    // Die Basisklasse aktualisiert im Hintergrund einfach 'currentSpeed'.
  }

  // --- DIE NEUE, "DUMME" SENDER-LOOP ---
  @override
  Future<void> senderLoop() async {
    while (isRunning && writeCharacteristic != null) {
      // KEINE MATHEMATIK MEHR HIER! 
      // Das Ramping übernimmt das zentrale Gehirn (TrainController).
      // Wir holen uns einfach den von dort vorbereiteten currentSpeed-Wert.

      String hexA = _pctToHex(currentSpeed);
      String hexD = currentSpeed != 0 ? _pctToHex(-currentSpeed) : "0000";
      String hexB = lightB > 0 ? (config.autoLight ? (lastDirForward ? "7FFF" : "81FF") : _pctToHex(lightB.toDouble())) : "0000";
      String hexC = _pctToHex(lightC.toDouble());
      
      String cmdStr = "T1440${hexA}${hexB}${hexC}000${hexD}W";
      
      try {
        await writeCharacteristic!.write([0x01], withoutResponse: true);
        await writeCharacteristic!.write(utf8.encode(cmdStr), withoutResponse: true);
      } catch (e) { 
        break; 
      }
      
      // Fester 100ms Heartbeat (hält die Lok am Leben und verhindert BLE-Spam)
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void setLight(String port, bool isOn) {
    int val = isOn ? 100 : 0;
    if (port.toUpperCase() == 'B') lightB = val;
    if (port.toUpperCase() == 'C') lightC = val;
    onStatusChanged?.call();
  }

  @override
  void updateAutoLight() {}  
}