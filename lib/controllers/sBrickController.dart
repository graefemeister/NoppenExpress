import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'train_controller.dart'; 

class SBrickController extends TrainController {
  static const String sBrickServiceUuid = "4dc591b0-857c-41de-b5f1-15abda665b0c";
  static const String sBrickCharacteristicUuid = "02b8cbcc-0e25-4bda-8790-a15f53e6010f";

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _heartbeatTimer;
  Timer? _batteryTimer;
  
  final Map<int, List<int>> _lastSentCommands = {};
  final Map<int, DateTime> _lastSentTimes = {}; 

  SBrickController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    try {
      device = BluetoothDevice.fromId(mac);
      await device!.connect(timeout: const Duration(seconds: 5), autoConnect: false);

      List<BluetoothService> services = await device!.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == sBrickServiceUuid) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == sBrickCharacteristicUuid) {
              writeCharacteristic = char;
              break;
            }
          }
        }
      }

      if (writeCharacteristic == null) {
        debugPrint("S-Brick Charakteristik nicht gefunden!");
        await disconnect();
        return;
      }

      _connectionSubscription = device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          isRunning = false;
          _heartbeatTimer?.cancel();
          onStatusChanged?.call();
        }
      });

      isRunning = true;
      _lastSentCommands.clear(); 
      _lastSentTimes.clear(); 

      // TELEMETRIE: SBrick ADC-Spannungsabfrage abonnieren
      try {
        await writeCharacteristic!.setNotifyValue(true);
        writeCharacteristic!.onValueReceived.listen((data) {
          if (data.length >= 2) {
            int rawAdc = data[0] + (data[1] << 8);
            if (rawAdc > 0) {
              // Formel: (rawAdc / 16.0) * (1.22 / 2047.0) * 11.0 ≈ rawAdc * 0.00041015 V
              double voltage = (rawAdc / 16.0) * (1.22 / 2047.0) * 11.0;
              // 9V-Batteriebox (6x AA): ca. 6.0V = 0% bis 9.6V = 100%
              double pct = ((voltage - 6.0) / (9.6 - 6.0)) * 100.0;
              batteryLevel = pct.round().clamp(0, 100);
              onStatusChanged?.call();
            }
          }
        });
        writeCharacteristic!.write([0x0F, 0x00], withoutResponse: true);
      } catch (e) {
        debugPrint("S-Brick Battery Telemetrie Fehler: $e");
      }

      // Periodischer Battery-Query alle 5 Sekunden
      _batteryTimer?.cancel();
      _batteryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (isRunning && writeCharacteristic != null) {
          try {
            writeCharacteristic!.write([0x0F, 0x00], withoutResponse: true);
          } catch (_) {}
        }
      });

      onStatusChanged?.call();

      // WICHTIG: Startet den Hintergrund-Heartbeat für den S-Brick Watchdog!
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (isRunning) {
          sendHardwareCommand();
        }
      });

    } catch (e) {
      debugPrint("S-Brick Verbindungsfehler: $e");
      await disconnect();
    }
  }

  @override
  void sendHardwareCommand() {
    if (writeCharacteristic == null || !isRunning) return;

    final portMap = {'A': 0, 'B': 1, 'C': 2, 'D': 3};
    DateTime now = DateTime.now();

    portMap.forEach((portKey, portId) {
      String role = config.portSettings[portKey] ?? 'none';
      if (role == 'none') return;

      int power = getPowerForRole(role, portKey); 
      List<int> command;

      if (power == 0) {
        command = [0x00, portId]; 
      } else {
        int rawSpeed = (power.abs() * 2.54).round().clamp(0, 254);
        int directionByte = power > 0 ? 0x00 : 0x01; 
        command = [0x01, portId, directionByte, rawSpeed]; 
      }

      bool isSame = _isSameCommand(_lastSentCommands[portId], command);
      bool timeToRefresh = false;

      // Watchdog-Limit des S-Bricks ist 500ms. Wir feuern sicherheitshalber alle 300ms!
      if (_lastSentTimes.containsKey(portId)) {
        if (now.difference(_lastSentTimes[portId]!).inMilliseconds >= 300) {
          timeToRefresh = true;
        }
      } else {
        timeToRefresh = true; 
      }

      // Senden, wenn sich etwas ändert ODER der Watchdog hungrig ist
      if (!isSame || timeToRefresh) {
        _lastSentCommands[portId] = command;
        _lastSentTimes[portId] = now;
        _sendSBrickCommand(command);
      }
    });
  }

  bool _isSameCommand(List<int>? cmd1, List<int> cmd2) {
    if (cmd1 == null || cmd1.length != cmd2.length) return false;
    for (int i = 0; i < cmd1.length; i++) {
      if (cmd1[i] != cmd2[i]) return false;
    }
    return true;
  }

  void _sendSBrickCommand(List<int> command) {
    try {
      writeCharacteristic!.write(command, withoutResponse: true);
    } catch (e) {
      // debugPrint("Fehler beim S-Brick Write: $e");
    }
  }

  @override
  Future<void> senderLoop() async {
    // Bleibt leer, da wir den Timer oben nutzen, was deutlich sicherer 
    // gegen Blockaden ist als eine endlose while-Schleife.
  }

  @override
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _batteryTimer?.cancel();
    _batteryTimer = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await super.disconnect(); 
  }
}