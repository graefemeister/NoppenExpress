import 'train_controller.dart';
import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 

class GenericQuadController extends TrainController {
  
  // NEU: Wir speichern alle schreibbaren Kanäle, nicht nur einen!
  final List<BluetoothCharacteristic> _allWriteChars = [];

  GenericQuadController(super.config) {
    print("GenericQuad: Controller wurde geladen.");
  }

  @override
  Future<void> connectAndInitialize() async {
    print("GenericQuad: Warte auf Scanner-Stop...");
    await Future.delayed(const Duration(milliseconds: 800));
    
    print("GenericQuad: Starte Verbindung mit ${config.mac}...");
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
      
      // SHOTGUN: Sammle ALLE schreibbaren Kanäle
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            _allWriteChars.add(characteristic);
            print("GenericQuad: Schreibkanal gefunden: ${characteristic.uuid}");
          }
        }
      }

      if (_allWriteChars.isNotEmpty) {
        print("GenericQuad: ${_allWriteChars.length} Kanäle gefunden. Starte Motor-Loop.");
        isRunning = true;
        onStatusChanged?.call();
        senderLoop();
      } else {
        print("GenericQuad ❌ FEHLER: Hub hat keine schreibbaren Kanäle!");
      }
    } catch (e) {
      print("GenericQuad Connect/Init Error: $e");
    }
  }

  int _pctToByte(double pct) {
    if (pct == 0) return 0;
    int val = pct.round().clamp(-100, 100);
    return val < 0 ? (256 + val) : val;
  }

  @override
  Future<void> senderLoop() async {
    print("GenericQuad: Sender-Loop gestartet!");

    while (isRunning && _allWriteChars.isNotEmpty) {
      // 1. KEIN RAMPING FÜR DIESEN TEST!
      // Der Befehl springt sofort auf den Wert des Sliders (z.B. direkt auf 100%)
      currentSpeed = targetSpeed; 
      
      int speedBVal = 0;
      if (lightB > 0) {
        speedBVal = config.autoLight ? (lastDirForward ? 100 : -100) : lightB;
      }

      int speedA = _pctToByte(currentSpeed);
      int speedB = _pctToByte(speedBVal.toDouble());
      int speedC = _pctToByte(lightC.toDouble());
      int speedD = 0;

      List<int> bytes = [0xAB, 0xCD, 0x01, speedA, speedB, speedC, speedD];
      int checksum = (bytes[3] + bytes[4] + bytes[5] + bytes[6]) & 0xFF;
      bytes.add(checksum);
      
      // 2. RÖNTGENBLICK: Zeigt uns EXACT, was an den Hub gesendet wird
      String hexOut = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      print("GenericQuad TX (Speed: ${currentSpeed}%): $hexOut");
      
      // Shotgun Fire
      for (var char in _allWriteChars) {
        try {
          await char.write(bytes, withoutResponse: true); // Wireshark sagt: Without Response (0x52)
        } catch (e) {}
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
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
  void updateAutoLight() { }  
}