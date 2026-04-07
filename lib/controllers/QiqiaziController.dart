import 'train_controller.dart';
import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'dart:convert';                                 

class QiqiaziController extends TrainController {
  QiqiaziController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    debugPrint("Qiqiazi: Starte Verbindung zu ${config.mac}...");
    device = BluetoothDevice.fromId(config.mac);

    // 1. Connection-Listener (Exakt wie MouldKing)
    device!.connectionState.listen((state) {
      debugPrint("Qiqiazi: Verbindungsstatus geändert: $state");
      if (state == BluetoothConnectionState.disconnected && isRunning) {
        isRunning = false;
        onStatusChanged?.call();
      }
    });

    try {
      // Verbindung herstellen (mit Catch für "already connected")
      await device!.connect().catchError((e) => debugPrint("Qiqiazi: Connect Hinweis: $e")); 
      
      // Kurze Pause wie im MouldKing
      await Future.delayed(const Duration(milliseconds: 500));
      
      debugPrint("Qiqiazi: Suche Services...");
      List<BluetoothService> services = await device!.discoverServices();
      
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // Wir suchen nach der Qiqiazi-Schreib-Charakteristik FFF2
          if (characteristic.uuid.toString().toLowerCase().contains("fff2")) {
            writeCharacteristic = characteristic;
            debugPrint("Qiqiazi: Schreib-Charakteristik gefunden: ${characteristic.uuid}");
          }
        }
      }

      if (writeCharacteristic != null) {
        // Hier setzen wir die Flags, die das UI braucht!
        isRunning = true;
        debugPrint("Qiqiazi: isRunning ist jetzt TRUE. Melde Status an UI...");
        
        // WICHTIG: Das UI muss erfahren, dass isRunning jetzt true ist
        onStatusChanged?.call();
        
        // Initialer Stopp-Befehl
        _sendRaw(0, 0, 0, 0);
        
        // Start der Sende-Schleife
        senderLoop();
      } else {
        debugPrint("Qiqiazi: FEHLER - FFF2 Charakteristik nicht gefunden!");
      }
    } catch (e) {
      debugPrint("Qiqiazi: Schwerer Fehler bei Initialisierung: $e");
      isRunning = false;
      onStatusChanged?.call();
    }
  }

  @override
  Future<void> senderLoop() async {
    debugPrint("Qiqiazi: SenderLoop gestartet");
    while (isRunning && writeCharacteristic != null) {
      // --- 1. Ramping Logik (Exakt wie MouldKing) ---
      double step = (targetSpeed.abs() > currentSpeed.abs()) ? config.rampStep : 3.0;
      
      if (currentSpeed == 0 && targetSpeed != 0) {
        currentSpeed = targetSpeed > 0 ? 20.0 : -20.0;
      }
      
      if (currentSpeed < targetSpeed) {
        currentSpeed = (currentSpeed + step > targetSpeed) ? targetSpeed : currentSpeed + step;
      } else if (currentSpeed > targetSpeed) {
        currentSpeed = (currentSpeed - step < targetSpeed) ? targetSpeed : currentSpeed - step;
      }

      // --- 2. Port-Mapping (A/D Motor, B/C Licht) ---
      int b5 = 0; int b6 = 0; int b7 = 0; int b8 = 0;
      int absSpeed = (currentSpeed.abs() * 2.55).toInt().clamp(0, 255);

      // SLOT 1: Motor A + Licht B
      if (currentSpeed.abs() > 0.1) {
        b5 |= (currentSpeed > 0 ? 1 : 2); 
        b6 = absSpeed;
      }
      if (lightB > 0) {
        b5 |= 4; 
        if (b6 == 0) b6 = 255; 
      }

      // SLOT 2: Licht C + Motor D (Invertiert)
      if (currentSpeed.abs() > 0.1) {
        b7 |= (currentSpeed > 0 ? 8 : 4); 
        b8 = absSpeed;
      }
      if (lightC > 0) {
        b7 |= 1; 
        if (b8 == 0) b8 = 255; 
      }

      await _sendRaw(b5, b6, b7, b8);
      await Future.delayed(const Duration(milliseconds: 100));
    }
    debugPrint("Qiqiazi: SenderLoop beendet");
  }

  Future<void> _sendRaw(int b5, int b6, int b7, int b8) async {
    if (writeCharacteristic == null) return;
    
    List<int> cmd = [0x5A, 0x6B, 0x02, 0x00, 0x05, b5, b6, b7, b8, 0x01, 0x00];
    int sum = 0;
    for (int i = 0; i <= 9; i++) sum += cmd[i];
    cmd[10] = sum & 0xFF;

    try {
      await writeCharacteristic!.write(cmd, withoutResponse: false);
    } catch (e) {
      debugPrint("Qiqiazi: Schreibfehler: $e");
      isRunning = false;
      onStatusChanged?.call();
    }
  }

  // --- Basis-Methoden ---
  @override
  void updateAutoLight() {
    if (config.autoLight) {
      bool shouldBeOn = targetSpeed.abs() > 0.1;
      setLight('B', shouldBeOn);
      setLight('C', shouldBeOn);
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
  void stop() => targetSpeed = 0;

  @override
  void emergencyStop() {
    targetSpeed = 0;
    currentSpeed = 0;
    _sendRaw(0, 0, 0, 0);
  }
}