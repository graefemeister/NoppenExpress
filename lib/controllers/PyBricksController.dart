import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'train_controller.dart'; 

class PyBricksController extends TrainController {
  // UUIDs für den Nordic UART Service (Standard bei Pybricks)
  final String serviceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"; 
  final String writeCharUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";  
  final String notifyCharUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; 

  bool _isSending = false;

  PyBricksController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    String expectedHubName = config.name ?? "Pybricks Hub"; 
    debugPrint("PyBricks 🔍 Suche nach: '$expectedHubName'...");

    BluetoothDevice? foundDevice;
    var scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.advertisementData.advName == expectedHubName || r.device.platformName == expectedHubName) {
          foundDevice = r.device;
          FlutterBluePlus.stopScan(); 
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    scanSubscription.cancel();

    if (foundDevice == null) return;
    device = foundDevice;

    try {
      await device!.connect();
      await Future.delayed(const Duration(milliseconds: 600));
      List<BluetoothService> services = await device!.discoverServices();

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == writeCharUuid) {
              writeCharacteristic = characteristic;
            }
            if (characteristic.uuid.toString().toLowerCase() == notifyCharUuid) {
              await characteristic.setNotifyValue(true);
              // Hier hören wir auf das Feedback vom Hub
              characteristic.lastValueStream.listen(_handleHubFeedback);
            }
          }
        }
      }

      if (writeCharacteristic != null) {
        isRunning = true;
        
        // REPL-Handshake: Wir schicken ein \n, um sicherzugehen, dass das Skript lauscht
        await _sendRaw("\n"); 
        
        onStatusChanged?.call();
        debugPrint("PyBricks 🟢 Hybrid-Schnittstelle bereit!");
      }
    } catch (e) {
      debugPrint("PyBricks ❌ Fehler: $e");
    }
  }

  // --- FEEDBACK-LOGIK (Die Galanterie) ---
  void _handleHubFeedback(List<int> data) {
    if (data.isEmpty) return;
    String msg = utf8.decode(data).trim();
    
    // Wir suchen nach "V_ACTUAL:XX" im Textstrom des Hubs
    if (msg.contains("V_ACTUAL:")) {
      try {
        final parts = msg.split("V_ACTUAL:");
        if (parts.length > 1) {
          // Wir nehmen den ersten Wert nach dem Trenner
          String valStr = parts[1].split("\n")[0].trim();
          double hubSpeed = double.parse(valStr);
          
          // NUR wenn der Wert stark abweicht, updaten wir das UI 
          // (Vermeidet Flackern beim Schieben des Sliders)
          if ((hubSpeed - currentSpeed).abs() > 1) {
            currentSpeed = hubSpeed;
            onStatusChanged?.call(); // Slider in der UI bewegt sich mit!
            debugPrint("PyBricks 🔄 Sync von Hub: $hubSpeed");
          }
        }
      } catch (e) {
        debugPrint("PyBricks ⚠️ Fehler beim Parsen: $msg");
      }
    }
  }

  // --- SENDE-LOGIK ---
  Future<void> _sendToHub(String cmd) async {
    if (writeCharacteristic == null || !isRunning || _isSending) return;
    
    _isSending = true;
    try {
      // WICHTIG: Das \n ist das Signal für das Python-Skript (usys.stdin.read)
      await writeCharacteristic!.write(utf8.encode("$cmd\n"), withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 50)); 
    } finally {
      _isSending = false;
    }
  }

  @override
  void sendHardwareCommand() {
    // Wandelt den Slider-Wert (-100 bis 100) in das Protokoll "V:XX" um
    int s = currentSpeed.round().clamp(-100, 100);
    _sendToHub("V:$s");
  }

  @override
  void setLight(String port, bool isOn) {
    // Lichtsteuerung via "L:XX"
    _sendToHub("L:${isOn ? 100 : 0}");
  }

  // Hilfsmethode für Initialisierung
  Future<void> _sendRaw(String text) async {
    if (writeCharacteristic != null) {
      await writeCharacteristic!.write(utf8.encode(text), withoutResponse: true);
    }
  }

  @override void updateAutoLight() {}
  @override Future<void> senderLoop() async {}
}