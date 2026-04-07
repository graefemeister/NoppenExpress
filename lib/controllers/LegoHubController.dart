import 'train_controller.dart';
import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'dart:convert';                                 
import 'train_controller.dart';

class LegoHubController extends TrainController {
  final String serviceUuid = "00001623-1212-efde-1623-785feabcd123";
  final String charUuid = "00001624-1212-efde-1623-785feabcd123";

  LegoHubController(super.config);

  @override
Future<void> connectAndInitialize() async {
  device = BluetoothDevice.fromId(config.mac);

  // Status-Überwachung (wie gehabt)
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
    // Wir setzen subscribeToServicesChanged auf FALSE
    List<BluetoothService> services = await device!.discoverServices(
      subscribeToServicesChanged: false 
    );
    
    for (var service in services) {
      // Wir suchen NUR nach der LEGO-Service UUID
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
      senderLoop();
    } else {
      // Falls wir nichts finden, trennen wir sauber, um keinen Zombie-GATT zu haben
      await device!.disconnect();
    }
  } catch (e) {
    debugPrint("LEGO Hub Verbindungsfehler: $e");
    isRunning = false;
    onStatusChanged?.call();
  }
}

  void _sendPortSpeed(int portIndex, int speed, bool invert) {
    if (writeCharacteristic == null) return;
    int finalSpeed = invert ? -speed : speed;
    finalSpeed = finalSpeed.clamp(-100, 100);

    List<int> cmd = [
      0x08, 0x00, 0x81, portIndex, 0x11, 0x51, 0x00, finalSpeed.toUnsigned(8)
    ];
    writeCharacteristic!.write(cmd, withoutResponse: true);
  }

  @override
  void setLight(String portName, bool on) {
    if (writeCharacteristic == null) return;
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
  Future<void> senderLoop() async {
    int lastSentSpeedInt = -999;
    while (isRunning && writeCharacteristic != null) {
      if (currentSpeed < targetSpeed) {
        currentSpeed += config.rampStep;
        if (currentSpeed > targetSpeed) currentSpeed = targetSpeed;
      } else if (currentSpeed > targetSpeed) {
        currentSpeed -= config.rampStep;
        if (currentSpeed < targetSpeed) currentSpeed = targetSpeed;
      }

      int speedInt = currentSpeed.round();
      if (speedInt != lastSentSpeedInt) {
        for (var port in ['A', 'B']) {
          String setting = config.portSettings[port] ?? 'none';
          if (setting.contains('motor')) {
            if (port == 'B' && config.autoLight && config.portSettings['B'] == 'light') continue;
            _sendPortSpeed(port == 'A' ? 0 : 1, speedInt, setting == 'motor_inv');
          }
        }
        lastSentSpeedInt = speedInt;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  void updateAutoLight() {
    if (writeCharacteristic == null || !config.autoLight) return;
    config.portSettings.forEach((port, setting) {
      if (setting == 'light') {
        _sendPortSpeed(port == 'A' ? 0 : 1, lastDirForward ? 100 : 0, false);
      }
    });
  }
}