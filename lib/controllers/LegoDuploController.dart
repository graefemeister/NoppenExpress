import 'dart:async';
import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'train_controller.dart';

class LegoDuploController extends TrainController {
  final String serviceUuid = "00001623-1212-efde-1623-785feabcd123";
  final String charUuid = "00001624-1212-efde-1623-785feabcd123";

  int _currentColorIndex = 10; // Weiß
  int _lastSentColor = -1;     // Cache, um BLE-Spam beim Ramping zu verhindern
  
  bool isBlocked = false;
  StreamSubscription<List<int>>? _subscription;

  int _lastWheelValue = -1;
  DateTime? _lastMovementDetected;
  
  LegoDuploController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    try {
      device = BluetoothDevice.fromId(config.mac);
      await device!.connect(timeout: const Duration(seconds: 5));

      List<BluetoothService> services = await device!.discoverServices();
      for (var s in services) {
        if (s.uuid.toString().toLowerCase() == serviceUuid) {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() == charUuid) {
              writeCharacteristic = c;
            }
          }
        }
      }

      if (writeCharacteristic != null) {
        isRunning = true;
        await writeCharacteristic!.setNotifyValue(true);
        _subscription?.cancel();
        _subscription = writeCharacteristic!.onValueReceived.listen(_handleNotification);
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Initialisierung des Hub-Protokolls
        await writeCharacteristic!.write([0x05, 0x00, 0x01, 0x02, 0x02], withoutResponse: false);
        // Aktivierung des Sound-Ports
        await writeCharacteristic!.write([0x0a, 0x00, 0x41, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x01], withoutResponse: false);
        // Aktivierung des Rad-Sensors (Port 18)
        await writeCharacteristic!.write([0x0a, 0x00, 0x41, 0x12, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01], withoutResponse: false);        
        
        // Initiale Farbe senden
        _sendColor(_currentColorIndex);
        onStatusChanged?.call();
        
        // Startet jetzt nur noch den Blockade-Wächter
        senderLoop();
      }
    } catch (e) {
      debugPrint("Verbindungsfehler: $e");
    }
  }

  void _handleNotification(List<int> data) {
    // 0x45 = Sensor-Wert hat sich geändert, 0x12 = Port 18 (Tacho)
    if (data.length >= 5 && data[2] == 0x45 && data[3] == 0x12) {
      int currentWheelValue = data[4]; 
      
      // Hat sich das Rad weitergedreht?
      if (currentWheelValue != _lastWheelValue) {
        _lastWheelValue = currentWheelValue;       
        _lastMovementDetected = DateTime.now();    // Stoppuhr auf Null setzen!
      }
    }
  }

  // --- DIE HARDWARE-METHODE DER BASISKLASSE ---
  @override
  void sendHardwareCommand() {
    if (!isRunning || writeCharacteristic == null) return;
    
    // 1. Wir holen die Motor-Power über die Rollen-Logik (Port A ist unser logischer Motor)
    String roleA = config.portSettings['A'] ?? 'motor';
    int speedInt = getPowerForRole(roleA).clamp(-100, 100);

    // 2. Stoppuhr aufziehen und verwalten
    if (speedInt != 0 && _lastMovementDetected == null) {
      _lastMovementDetected = DateTime.now();
      if (isBlocked) {
        isBlocked = false; // Blockade aufheben beim Neustart
      }
    } else if (speedInt == 0 && targetSpeed == 0) {
      _lastMovementDetected = null;
    }

    // 3. Befehl an Port 0 (Interner Motor) senden
    // Während des Ramping-Prozesses kein Feedback (0x01) fordern, um BLE zu schonen.
    // Erst beim Erreichen des Zielwerts Feedback (0x11) fordern.
    bool isAtTarget = (currentSpeed.round() == targetSpeed.round());
    int executionMode = isAtTarget ? 0x11 : 0x01;

    writeCharacteristic?.write([0x08, 0x00, 0x81, 0x00, executionMode, 0x51, 0x00, speedInt.toUnsigned(8)], withoutResponse: true);

    // 4. Licht-Status prüfen und ggf. umschalten (isLightOn kommt aus der Basisklasse)
    int targetColor = isLightOn ? _currentColorIndex : 0;
    if (targetColor != _lastSentColor) {
      _sendColor(targetColor);
    }
  }

  // --- DER WATCHDOG ---
  @override
  Future<void> senderLoop() async {
    while (isRunning) {
      // Wenn Zug fahren soll (target != 0) und wir eigentlich eine Bewegung registriert hatten
      if (targetSpeed != 0 && _lastMovementDetected != null && !isBlocked) {
        final timeSinceMove = DateTime.now().difference(_lastMovementDetected!).inMilliseconds;
        
        // Wenn über 2,5 Sekunden kein Impuls von Port 18 kam:
        if (timeSinceMove > 2500) {
          debugPrint(">>> [SYSTEM-SYNC] Lok hat physisch gestoppt. Blockade erkannt!");
          
          isBlocked = true; 
          
          // Wir rufen emergencyStop() der Basisklasse auf. Das macht ALLES automatisch:
          // Setzt currentSpeed=0, targetSpeed=0, killt Ramping-Timer, funkt sofort 0
          // und pusht das UI-Update. Absolut sauber!
          emergencyStop(); 
        }
      }
      
      // 200ms Schlafenszeit reichen für einen Watchdog völlig aus
      await Future.delayed(const Duration(milliseconds: 200)); 
    }
  }

  void playSound(int soundId) {
    writeCharacteristic?.write([0x08, 0x00, 0x81, 0x01, 0x11, 0x51, 0x01, soundId], withoutResponse: false);
  }

  void _sendColor(int colorIndex) {
    _lastSentColor = colorIndex;
    writeCharacteristic?.write([0x08, 0x00, 0x81, 0x11, 0x11, 0x51, 0x00, colorIndex], withoutResponse: true);
  }

  // Eigene LEGO Methode (Feuert z.B. der ActionChip im ControlPanel ab)
  void cycleColor() {
    List<int> colors = [10, 9, 7, 6, 3, 2];
    int currentPos = colors.indexOf(_currentColorIndex);
    _currentColorIndex = colors[(currentPos + 1) % colors.length];
    
    // Wenn die Farbe manuell durchgeschaltet wird, schalten wir das Licht automatisch "an"
    isLightOn = true; 
    _sendColor(_currentColorIndex);
    onStatusChanged?.call();
  }

  @override
  Future<void> disconnect() async {
    _subscription?.cancel(); // LEGO-spezifische Listener killen
    
    // Alles andere (isRunning=false, Ramping stoppen, Bluetooth trennen) 
    // übernimmt die Basisklasse:
    await super.disconnect(); 
  }
}