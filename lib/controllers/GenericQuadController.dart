import 'train_controller.dart';
import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 

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
        senderLoop();
      } else {
        debugPrint("GenericQuad ❌ FEHLER: Hub hat keine schreibbaren Kanäle!");
      }
    } catch (e) {
      debugPrint("GenericQuad Connect/Init Error: $e");
    }
  }

  int _pctToByte(double pct) {
    if (pct == 0) return 0;
    int val = pct.round().clamp(-100, 100);
    return val < 0 ? (256 + val) : val;
  }

  // --- NEU: DYNAMISCHE PORT-ZUWEISUNG ---
  // Prüft die UI-Konfiguration (config.portSettings) und gibt den passenden Wert zurück
  int _getSpeedForPort(String portName, int manualLightValue) {
    String setting = config.portSettings[portName] ?? 'none';
    
    if (setting == 'motor') {
      return _pctToByte(currentSpeed);
    } else if (setting == 'motor_inv') {
      return _pctToByte(-currentSpeed);
    } else if (setting == 'light') {
      if (config.autoLight) {
        return _pctToByte(lastDirForward ? 100.0 : -100.0);
      } else {
        return _pctToByte(manualLightValue.toDouble());
      }
    }
    return 0; // Falls 'none' oder nicht konfiguriert
  }

  @override
  void sendHardwareCommand() {
    // BLE Flood Protection: Senden bleibt exklusiv in der senderLoop()
  }

  @override
  Future<void> senderLoop() async {
    debugPrint("GenericQuad: Sender-Loop gestartet!");

    while (isRunning && _allWriteChars.isNotEmpty) {
      
      // Nutzt nun dynamisch die Konfiguration aus der Werkstatt!
      int speedA = _getSpeedForPort('A', lightA);
      int speedB = _getSpeedForPort('B', lightB);
      int speedC = _getSpeedForPort('C', lightC);
      int speedD = _getSpeedForPort('D', 0); // Basisklasse hat kein lightD, daher Fallback auf 0

      List<int> bytes = [0xAB, 0xCD, 0x01, speedA, speedB, speedC, speedD];
      int checksum = (bytes[3] + bytes[4] + bytes[5] + bytes[6]) & 0xFF;
      bytes.add(checksum);
      
      String hexOut = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      
      // Nur bei Geschwindigkeit > 0 die Console spammen, um den Log lesbar zu halten
      if (currentSpeed != 0 || targetSpeed != 0) {
        debugPrint("GenericQuad TX (Speed: ${currentSpeed.toStringAsFixed(1)}%): $hexOut");
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

  @override
  void setLight(String port, bool isOn) {
    int val = isOn ? 100 : 0;
    if (port.toUpperCase() == 'A') lightA = val;
    if (port.toUpperCase() == 'B') lightB = val;
    if (port.toUpperCase() == 'C') lightC = val;
    onStatusChanged?.call();
  }

  @override
  void updateAutoLight() { }  
}