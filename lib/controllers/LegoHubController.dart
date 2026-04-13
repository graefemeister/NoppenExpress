import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'train_controller.dart';
import 'dart:async';

class LegoHubController extends TrainController {
  final String serviceUuid = "00001623-1212-efde-1623-785feabcd123";
  final String charUuid = "00001624-1212-efde-1623-785feabcd123";

  LegoHubController(super.config);

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
      // 1. Sanfter Start: Erstmal alles stoppen
      try { await FlutterBluePlus.stopScan(); } catch (_) {}
      try { await device!.disconnect(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 800));

      // 2. Verbinden ohne AutoConnect (wichtig für Android)
      await device!.connect(timeout: const Duration(seconds: 5), autoConnect: false);
      
      // 3. WICHTIG: Services entdecken, aber 2a05 ignorieren!
      List<BluetoothService> services = await device!.discoverServices(
        subscribeToServicesChanged: false 
      );
      
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
        // Keine senderLoop() mehr nötig, da "On-Demand" gefunkt wird!
      } else {
        await device!.disconnect();
      }
    } catch (e) {
      debugPrint("LEGO Hub Verbindungsfehler: $e");
      isRunning = false;
      onStatusChanged?.call();
    }
  }

  // --- HILFSMETHODE FÜR DAS LEGO PROTOKOLL ---
  void _sendPortSpeed(int portIndex, int speed, bool invert) {
    if (writeCharacteristic == null || !isRunning) return;
    int finalSpeed = invert ? -speed : speed;
    finalSpeed = finalSpeed.clamp(-100, 100);

    List<int> cmd = [
      0x08, 0x00, 0x81, portIndex, 0x11, 0x51, 0x00, finalSpeed.toUnsigned(8)
    ];
    writeCharacteristic!.write(cmd, withoutResponse: true);
  }

  // --- DIE HARDWARE-METHODE DER BASISKLASSE ---
  @override
  void sendHardwareCommand() {
    // Wird automatisch vom Ramping-Timer aufgerufen, wenn sich currentSpeed ändert
    if (!isRunning || writeCharacteristic == null) return;
    
    int speedInt = currentSpeed.round();
    
    // An alle Ports senden, die als Motor konfiguriert sind
    for (var port in ['A', 'B']) {
      String setting = config.portSettings[port] ?? 'none';
      if (setting.contains('motor')) {
        _sendPortSpeed(port == 'A' ? 0 : 1, speedInt, setting == 'motor_inv');
      }
    }
  }

  // --- DIE ALTE SENDER-LOOP WIRD ARBEITSLOS ---
  @override
  Future<void> senderLoop() async {
    // Bleibt leer, da das Lego-Protokoll keinen ständigen Heartbeat benötigt.
  }

  @override
  void setLight(String portName, bool on) {
    if (writeCharacteristic == null || !isRunning) return;
    
    if (config.portSettings[portName] == 'light') {
      int portIndex = (portName == 'A') ? 0 : 1;
      int brightness = on ? 100 : 0;
      if (portName == 'A') lightA = brightness;
      if (portName == 'B') lightB = brightness;
      
      _sendPortSpeed(portIndex, brightness, false);
      onStatusChanged?.call();
    }
  }

  @override
  void updateAutoLight() {
    if (writeCharacteristic == null || !isRunning || !config.autoLight) return;
    
    // Wird von der Basisklasse aufgerufen, wenn die Richtung wechselt
    config.portSettings.forEach((port, setting) {
      if (setting == 'light') {
        _sendPortSpeed(port == 'A' ? 0 : 1, lastDirForward ? 100 : 0, false);
      }
    });
  }
}