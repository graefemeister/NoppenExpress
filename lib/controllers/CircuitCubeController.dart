import 'dart:async';
import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
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
      // Die endlose senderLoop() wird hier nicht mehr gestartet, 
      // da wir ab sofort "On-Demand" funken!
    }
  }

  // Die Funktion, die den Prozentwert (0-100) in das Cube-Format (0-255) umrechnet
  void _sendCommand(String channel, int speed) {
    if (writeCharacteristic == null || !isRunning) return;
    String dir = speed >= 0 ? "+" : "-";
    int cubeSpeed = ((speed.abs() / 100.0) * 255).round().clamp(0, 255);
    String command = "$dir${cubeSpeed.toString().padLeft(3, '0')}${channel.toLowerCase()}";
    writeCharacteristic!.write(command.codeUnits, withoutResponse: true);
  }

  // --- DIE ZENTRALE HARDWARE-METHODE ---
  @override
  void sendHardwareCommand() {
    // Wird von der Basisklasse aufgerufen, wann immer das Ramping 
    // die Geschwindigkeit ändert, oder bei einem Notstopp (currentSpeed = 0).
    config.portSettings.forEach((port, role) {
      if (role.toLowerCase() == 'motor') {
        _sendCommand(port, currentSpeed.toInt());
      }
    });
  }

  // --- DIE SENDER-LOOP IST JETZT ARBEITSLOS ---
  @override
  Future<void> senderLoop() async {
    // Bleibt komplett leer, da der Circuit Cube keinen Heartbeat braucht.
    // Alles wird effizient über sendHardwareCommand abgewickelt!
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
}