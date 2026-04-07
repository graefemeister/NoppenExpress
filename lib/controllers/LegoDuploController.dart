import 'train_controller.dart';
import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'dart:convert';                                 
import 'train_controller.dart';
import 'dart:async'; 


class LegoDuploController extends TrainController {
  final String serviceUuid = "00001623-1212-efde-1623-785feabcd123";
  final String charUuid = "00001624-1212-efde-1623-785feabcd123";

  int _currentColorIndex = 10; // Weiß
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
        // Aktivierung des Rad-Sensors (Port 18) ---
        await writeCharacteristic!.write([0x0a, 0x00, 0x41, 0x12, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01], withoutResponse: false);        _sendColor(10);
        onStatusChanged?.call();
        senderLoop();
      }
    } catch (e) {
      debugPrint("Verbindungsfehler: $e");
    }
  }

  void _handleNotification(List<int> data) {
    // 0x45 = Sensor-Wert hat sich geändert
    // 0x12 = Das ist Port 18 (unser Tacho!)
    if (data.length >= 5 && data[2] == 0x45 && data[3] == 0x12) {
      
      int currentWheelValue = data[4]; 
      
      // Hat sich das Rad weitergedreht?
      if (currentWheelValue != _lastWheelValue) {
        _lastWheelValue = currentWheelValue;       // Neuen Wert merken
        _lastMovementDetected = DateTime.now();    // Stoppuhr auf Null setzen!
      }
    }
  }

  @override
  Future<void> senderLoop() async {
    int lastSent = -999;
    double step = config.rampStep;

    while (isRunning) {
      // --- 1. Ramping (Sanftes Beschleunigen/Bremsen) ---
      if (currentSpeed < targetSpeed) {
        currentSpeed = (currentSpeed + step).clamp(-100, targetSpeed);
      } else if (currentSpeed > targetSpeed) {
        currentSpeed = (currentSpeed - step).clamp(targetSpeed, 100);
      }

      int speedInt = currentSpeed.round().clamp(-100, 100);

      // --- 2. Stoppuhr aufziehen und verwalten ---
      if (speedInt != 0 && _lastMovementDetected == null) {
        _lastMovementDetected = DateTime.now();
        if (isBlocked) {
          isBlocked = false;
          onStatusChanged?.call(); // Dem UI sagen, dass alles wieder gut ist
        }
      } else if (speedInt == 0 && targetSpeed == 0) {
        _lastMovementDetected = null;
      }

      // --- 3. Das System synchronisieren (Der Wächter) ---
      if (targetSpeed != 0 && _lastMovementDetected != null && !isBlocked) {
        final timeSinceMove = DateTime.now().difference(_lastMovementDetected!).inMilliseconds;
        
        // Wenn über 2,5 Sekunden kein Impuls von Port 18 kam:
        if (timeSinceMove > 2500) {
          debugPrint(">>> [SYSTEM-SYNC] Lok hat physisch gestoppt. App wird aktualisiert.");
          
          targetSpeed = 0;
          currentSpeed = 0;
          isBlocked = true; 
          
          onStatusChanged?.call(); // UI-Update anstoßen
        }
      }

      // --- 4. Befehle an den Motor (Port 0) senden ---
      if (speedInt != lastSent) {
        // Während des Hochfahrens kein Feedback (0x01), um Log zu schonen.
        // Erst beim Erreichen des Zielwerts Feedback (0x11) anfordern.
        bool isAtTarget = (speedInt == targetSpeed.round());
        int executionMode = isAtTarget ? 0x11 : 0x01;

        writeCharacteristic?.write([0x08, 0x00, 0x81, 0x00, executionMode, 0x51, 0x00, speedInt.toUnsigned(8)], withoutResponse: true);
        lastSent = speedInt;
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void playSound(int soundId) {
    writeCharacteristic?.write([0x08, 0x00, 0x81, 0x01, 0x11, 0x51, 0x01, soundId], withoutResponse: false);
  }

  void _sendColor(int colorIndex) {
    writeCharacteristic?.write([0x08, 0x00, 0x81, 0x11, 0x11, 0x51, 0x00, colorIndex], withoutResponse: true);
  }

  @override
  void setLight(String port, bool isOn) {
    _currentColorIndex = isOn ? 10 : 0;
    _sendColor(_currentColorIndex);
    lightA = isOn ? 100 : 0;
    onStatusChanged?.call();
  }

  @override
  void cycleColor() {
    List<int> colors = [10, 9, 7, 6, 3, 2];
    int currentPos = colors.indexOf(_currentColorIndex);
    _currentColorIndex = colors[(currentPos + 1) % colors.length];
    _sendColor(_currentColorIndex);
    lightA = 100;
    onStatusChanged?.call();
  }

  @override
  void updateAutoLight() {}

  @override
  Future<void> disconnect() async {
    _subscription?.cancel();
    isRunning = false;
    await device?.disconnect();
    super.disconnect();
  }
}