import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'train_controller.dart'; 

class PFxBrickController extends TrainController {
  PFxBrickController(TrainConfig config) : super(config);

  static const String pfxUartTxUuid = "49535343-1e4d-4bd9-ba61-23c647249616"; 

  final List<List<int>> _commandQueue = [];
  bool _isProcessingQueue = false;
  
  int _lastSentPowerA = -999;
  int _lastSentPowerB = -999;

  @override
  Future<void> connectAndInitialize() async {
    if (isRunning) return;
    device = BluetoothDevice.fromId(config.mac);
    
    try {
      await device!.connect(timeout: const Duration(seconds: 10), autoConnect: false);
      
      if (defaultTargetPlatform == TargetPlatform.android) {
        await device!.requestMtu(512);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      List<BluetoothService> services = await device!.discoverServices();
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.uuid.toString().toLowerCase() == pfxUartTxUuid) {
            writeCharacteristic = c;
          }
        }
      }
      
      if (writeCharacteristic != null) {
        isRunning = true;
        debugPrint("PFxBrick: Online. Broadcast-Modus aktiv.");
      }
    } catch (e) {
      debugPrint("PFx Connect Error: $e");
    }
  }

  // ==========================================================
  // NOTHALT: Sofortiger Direct-Write (Umgeht die Warteschlange)
  // ==========================================================
  @override
  void emergencyStop() {
    debugPrint("🚨 GLOBALER NOTHALT");
    
    // 1. Warteschlange leeren (Killt sofort alle laufenden Ramping-Befehle)
    _commandQueue.clear();

    // 2. UI-Status und App-Werte sofort auf 0 setzen
    super.emergencyStop();
    _lastSentPowerA = 0;
    _lastSentPowerB = 0;

    // 3. FAKT AUS LOG (Frame 1253): Nothalt ist Cmd 15 + Adresse 00. Keine Nullen!
    String payload = '1500';

    // 4. Sicher in die Queue legen. Da die Queue in Schritt 1 geleert wurde, 
    // ist dieser Befehl sofort als Nächstes an der Reihe. Keine Kollisionen!
    _commandQueue.add(_hexToBytes("5B5B5B${payload}5D5D5D"));
    _startQueueProcessing();

    debugPrint("✅ Nothalt: 5B5B5B15005D5D5D gesendet.");
  }

  // ==========================================================
  // SOUNDS & LICHTER (Nach offizieller PFx LUT-Tabelle)
  // ==========================================================
  Future<void> triggerRemoteAction(int buttonId, {int channel = 2}) async {
    if (!isRunning) return;

    // 1. Kanal-Index (0 bis 3)
    int chIndex = (channel - 1).clamp(0, 3);
    
    // 2. Adresse nach LUT berechnen: (Taste * 4) + Kanal
    int address = (buttonId * 4) + chIndex; 
    
    String addressHex = address.toRadixString(16).padLeft(2, '0').toUpperCase();
    
    // FAKT AUS LOG: Das Paket besteht nur aus Cmd 15 + Adresse. Keine Nullen!
    String payload = '15$addressHex';
    
    // Sicher über die Queue senden
    _commandQueue.add(_hexToBytes("5B5B5B${payload}5D5D5D"));
    _startQueueProcessing();
    
    debugPrint("📡 PFx Action: Channel $channel, Button $buttonId -> Sendet: 5B5B5B${payload}5D5D5D");
  }

  // ==========================================================
  // REGULÄRE STEUERUNG
  // ==========================================================
  @override
  void sendHardwareCommand() {
    if (!isRunning || writeCharacteristic == null) return;

    int targetA = getPowerForRole(config.portSettings['A'] ?? 'none');
    int targetB = getPowerForRole(config.portSettings['B'] ?? 'none');

    if (targetA != _lastSentPowerA) {
      _enqueueMotorCommand(1, targetA);
      _lastSentPowerA = targetA;
    }
    
    if (targetB != _lastSentPowerB) {
      _enqueueMotorCommand(2, targetB);
      _lastSentPowerB = targetB;
    }

    _startQueueProcessing();
  }

  @override
  Future<void> senderLoop() async {
    sendHardwareCommand();
  }

  void _enqueueMotorCommand(int channel, int power) {
    String payload;
    if (power == 0) {
      // Einzel-Stop für Kanal
      payload = '1300010$channel' + '00000000000000000000000000';
    } else {
      // Fahren (Kommando 7 + Kanal verschmolzen)
      int pfxSpeed = (power.abs() * 0.63).round().clamp(1, 63);
      int dirFlag = (power >= 0 ? 0x40 : 0x00);
      int speedWithDir = 0x80 + dirFlag + pfxSpeed; 
      String speedHex = speedWithDir.toRadixString(16).padLeft(2, '0').toUpperCase();
      
      payload = '13007$channel$speedHex' + '00000000000000000000000000';
    }
    
    _commandQueue.add(_hexToBytes("5B5B5B${payload}5D5D5D"));
  }

  void _startQueueProcessing() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_commandQueue.isNotEmpty) {
      List<int> nextCmd = _commandQueue.removeAt(0);
      try {
        if (writeCharacteristic != null) {
          await writeCharacteristic!.write(nextCmd, withoutResponse: false)
              .timeout(const Duration(milliseconds: 200));
        }
      } catch (e) {
        debugPrint("PFx Queue Error: $e");
      }
      // 40ms Atempause für den Brick
      await Future.delayed(const Duration(milliseconds: 40));
    }

    _isProcessingQueue = false;
  }

  List<int> _hexToBytes(String hexStr) {
    List<int> bytes = [];
    for (int i = 0; i < hexStr.length; i += 2) {
      bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}