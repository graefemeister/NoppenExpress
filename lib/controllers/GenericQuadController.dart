import 'dart:async';
import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'train_controller.dart';

class GenericQuadController extends TrainController {
  
  final List<BluetoothCharacteristic> _allWriteChars = [];

  GenericQuadController(super.config) {
    debugPrint("GenericQuad: Controller wurde geladen.");
  }

  @override
  Future<void> connectAndInitialize() async {
    debugPrint("GenericQuad: Warte auf Scanner-Stop...");
    await Future.delayed(const Duration(milliseconds: 800));
    
    debugPrint("GenericQuad: Starte Verbindung mit ${config.mac}...");
    device = BluetoothDevice.fromId(config.mac);

    device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && isRunning) {
        isRunning = false;
        onStatusChanged?.call();
      }
    });

    try {
      await device!.connect(timeout: const Duration(seconds: 5)); 
      await Future.delayed(const Duration(milliseconds: 500));
      
      List<BluetoothService> services = await device!.discoverServices();
      
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            _allWriteChars.add(characteristic);
            debugPrint("GenericQuad: Schreibkanal gefunden: ${characteristic.uuid}");
          }
        }
      }

      if (_allWriteChars.isNotEmpty) {
        debugPrint("GenericQuad: ${_allWriteChars.length} Kanäle gefunden. Starte Motor-Loop.");
        isRunning = true;
        onStatusChanged?.call();
        senderLoop(); // Loop starten für den Heartbeat
      } else {
        debugPrint("GenericQuad ❌ FEHLER: Hub hat keine schreibbaren Kanäle!");
      }
    } catch (e) {
      debugPrint("GenericQuad Connect/Init Error: $e");
    }
  }

  // Wandelt unsere -100 bis +100 Power in das Byte-Format des Hubs um
  int _pctToByte(int power) {
    if (power == 0) return 0;
    int val = power.clamp(-100, 100);
    return val < 0 ? (256 + val) : val;
  }

  @override
  void sendHardwareCommand() {
    // BLE Flood Protection: Wir senden hier nicht sofort!
    // Die Basisklasse (Ramping Timer, Buttons) triggert diese Methode, 
    // aber wir lassen die Werte einfach in der nächsten senderLoop()-Runde abholen.
  }

  @override
  Future<void> senderLoop() async {
    debugPrint("GenericQuad: Sender-Loop gestartet!");

    while (isRunning && _allWriteChars.isNotEmpty) {
      
      // 1. Wir fragen unsere intelligente Basisklasse nach der Power (-100 bis 100)
      int powerA = getPowerForRole(config.portSettings['A'] ?? 'none');
      int powerB = getPowerForRole(config.portSettings['B'] ?? 'none');
      int powerC = getPowerForRole(config.portSettings['C'] ?? 'none');
      int powerD = getPowerForRole(config.portSettings['D'] ?? 'none');

      // 2. Umrechnen in die Bytes für das Generic-Protokoll
      int speedA = _pctToByte(powerA);
      int speedB = _pctToByte(powerB);
      int speedC = _pctToByte(powerC);
      int speedD = _pctToByte(powerD);

      List<int> bytes = [0xAB, 0xCD, 0x01, speedA, speedB, speedC, speedD];
      int checksum = (bytes[3] + bytes[4] + bytes[5] + bytes[6]) & 0xFF;
      bytes.add(checksum);
      
      // Nur bei aktiven Werten die Konsole bespielen, um Spam zu vermeiden
      if (powerA != 0 || powerB != 0 || powerC != 0 || powerD != 0) {
        String hexOut = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        debugPrint("GenericQuad TX: $hexOut");
      }
      
      for (var char in _allWriteChars) {
        try {
          await char.write(bytes, withoutResponse: true); 
        } catch (e) {
          // Fehler ignorieren, damit die Loop nicht stirbt
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
}