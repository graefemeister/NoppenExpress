import 'train_controller.dart';
import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'dart:convert';                                 
import 'train_controller.dart';

class CircuitCubeController extends TrainController {
  final Map<String, bool> _activeLights = {'a': false, 'b': false, 'c': false};

  CircuitCubeController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    device = BluetoothDevice.fromId(config.mac);

    device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && isRunning) {
        isRunning = false;
        onStatusChanged?.call();
      }
    });

    await device!.connect(timeout: const Duration(seconds: 10));
    List<BluetoothService> services = await device!.discoverServices();
    for (var s in services) {
      if (s.uuid.toString().toLowerCase() == "6e400001-b5a3-f393-e0a9-e50e24dcca9e") {
        for (var c in s.characteristics) {
          if (c.uuid.toString().toLowerCase() == "6e400002-b5a3-f393-e0a9-e50e24dcca9e") {
            writeCharacteristic = c;
          }
        }
      }
    }

    if (writeCharacteristic != null) {
      isRunning = true;
      onStatusChanged?.call();
      senderLoop();
    }
  }

  void _sendCommand(String channel, int speed) {
    if (writeCharacteristic == null || !isRunning) return;
    String dir = speed >= 0 ? "+" : "-";
    int cubeSpeed = ((speed.abs() / 100.0) * 255).round().clamp(0, 255);
    String command = "$dir${cubeSpeed.toString().padLeft(3, '0')}${channel.toLowerCase()}";
    writeCharacteristic!.write(command.codeUnits, withoutResponse: true);
  }

  @override
  Future<void> senderLoop() async {
    while (isRunning) {
      if (currentSpeed != targetSpeed) {
        if (currentSpeed < targetSpeed) {
          currentSpeed += config.rampStep;
          if (currentSpeed > targetSpeed) currentSpeed = targetSpeed;
        } else if (currentSpeed > targetSpeed) {
          currentSpeed -= config.rampStep;
          if (currentSpeed < targetSpeed) currentSpeed = targetSpeed;
        }
        
        config.portSettings.forEach((port, role) {
          if (role.toLowerCase() == 'motor') _sendCommand(port, currentSpeed.toInt());
        });
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void setLight(String port, bool isOn) {
    String p = port.toLowerCase();
    _activeLights[p] = isOn;
    int val = isOn ? 100 : 0;
    if (p == 'b') lightB = val;
    if (p == 'c') lightC = val;

    if (!isOn) {
      _sendCommand(p, 0);
    } else {
      _sendCommand(p, config.autoLight ? (lastDirForward ? 100 : -100) : 100);
    }
    onStatusChanged?.call();
  }

  @override
  void updateAutoLight() {}

  @override
  void emergencyStop() {
    super.emergencyStop();
    config.portSettings.forEach((port, role) {
      if (role.toLowerCase() == 'motor') _sendCommand(port, 0);
    });
  }
}