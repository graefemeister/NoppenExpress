import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'train_controller.dart'; 

class SBrickController extends TrainController {
  static const String sBrickServiceUuid = "4dc591b0-857c-41de-b5f1-15abda665b0c";
  static const String sBrickCharacteristicUuid = "02b8cbcc-0e25-4bda-8790-a15f53e6010f";

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _heartbeatTimer;
  
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

      int power = getPowerForRole(role); 
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
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await super.disconnect(); 
  }
}