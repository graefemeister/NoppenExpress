import 'dart:async';
import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'train_controller.dart';

class CircuitCubeController extends TrainController {
  
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
    }
  }

  // Die Funktion, die den Prozentwert (-100 bis 100) in das Cube-Format umrechnet
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
    if (writeCharacteristic == null || !isRunning) return;

    // Der Circuit Cube hat in der Regel 3 Ports (A, B, C).
    // Wir klappern sie einfach ab und fragen unsere Basisklasse nach der Power!
    List<String> cubePorts = ['A', 'B', 'C'];

    for (String port in cubePorts) {
      String role = config.portSettings[port] ?? 'none';
      
      if (role != 'none') {
        int power = getPowerForRole(role);
        _sendCommand(port, power);
      } else {
        // Falls der Port explizit auf 'none' steht, zur Sicherheit auf 0 setzen
        _sendCommand(port, 0); 
      }
    }
  }

  // --- DIE SENDER-LOOP IST WEITERHIN ARBEITSLOS ---
  @override
  Future<void> senderLoop() async {
    // Bleibt komplett leer, da der Circuit Cube keinen Heartbeat braucht.
    // Alles wird effizient über sendHardwareCommand abgewickelt!
  }
}