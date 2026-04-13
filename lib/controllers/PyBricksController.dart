import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'train_controller.dart';

class PyBricksController extends TrainController {
  // Standard UART Service (NUS) - ideal für Kommunikation mit PyBricks
  final String serviceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"; 
  final String charUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";    

  PyBricksController(super.config) {
    debugPrint("PyBricks: Controller geladen.");
  }

  @override
  Future<void> connectAndInitialize() async {
    device = BluetoothDevice.fromId(config.mac);

    device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && isRunning) {
        isRunning = false;
        onStatusChanged?.call();
      }
    });

    try {
      // Ohne autoConnect für stabilere Android-Verbindungen
      await device!.connect(timeout: const Duration(seconds: 5), autoConnect: false);
      await Future.delayed(const Duration(milliseconds: 500));

      List<BluetoothService> services = await device!.discoverServices(subscribeToServicesChanged: false);

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == charUuid) {
              writeCharacteristic = characteristic;
            }
          }
        }
      }

      if (writeCharacteristic != null) {
        isRunning = true;
        onStatusChanged?.call();
        // Keine senderLoop() nötig! Wir funken On-Demand.
      } else {
        debugPrint("PyBricks ❌ FEHLER: UART Schreib-Charakteristik nicht gefunden!");
        await device!.disconnect();
      }
    } catch (e) {
      debugPrint("PyBricks Connect Error: $e");
      isRunning = false;
      onStatusChanged?.call();
    }
  }

  // --- HILFSMETHODE: TEXT AN DEN HUB SENDEN ---
  void _sendCommand(String command) {
    if (writeCharacteristic == null || !isRunning) return;
    
    // Wir hängen ein '\n' an, damit das Python-Skript weiß, dass der Befehl zu Ende ist
    List<int> bytes = utf8.encode("$command\n");
    
    try {
      writeCharacteristic!.write(bytes, withoutResponse: true);
      // debugPrint("PyBricks TX: $command"); // Auskommentieren für Debugging
    } catch (e) {
      debugPrint("PyBricks TX Error: $e");
    }
  }

  // --- DIE HARDWARE-METHODE DER BASISKLASSE ---
  @override
  void sendHardwareCommand() {
    if (!isRunning) return;

    int speedInt = currentSpeed.round().clamp(-100, 100);

    // Wir lesen deine dynamische Werkstatt-Konfiguration aus!
    config.portSettings.forEach((port, role) {
      if (role.toLowerCase() == 'motor') {
         _sendCommand("M:$port:$speedInt");
      } else if (role.toLowerCase() == 'motor_inv') {
         _sendCommand("M:$port:${-speedInt}");
      }
    });
  }

  @override
  Future<void> senderLoop() async {
    // Bleibt leer. Die Basisklasse kümmert sich um alles!
  }

  @override
  void setLight(String port, bool isOn) {
    int val = isOn ? 100 : 0;
    if (port.toUpperCase() == 'B') lightB = val;
    if (port.toUpperCase() == 'C') lightC = val;

    if (config.portSettings[port] == 'light') {
       _sendCommand("L:$port:$val");
    }
    onStatusChanged?.call();
  }

  @override
  void updateAutoLight() {
    if (!isRunning || !config.autoLight) return;

    config.portSettings.forEach((port, role) {
      if (role.toLowerCase() == 'light') {
        int val = lastDirForward ? 100 : 0;
        _sendCommand("L:$port:$val");
      }
    });
  }
}