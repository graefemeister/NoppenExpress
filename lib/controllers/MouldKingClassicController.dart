import 'train_controller.dart';
import 'dart:typed_data';           
import 'package:flutter/services.dart'; 
import 'package:flutter/foundation.dart';
import '../mould_king_40_protocol.dart'; 
import 'dart:async';
import 'dart:convert';

class MouldKingClassicController extends TrainController {
  bool isRunning = false;
  double _actualSpeed = 0.0; // Der gerampte Wert für den Antrieb
  
  static const platform = MethodChannel('com.noppenexpress/ble_native');
  void Function()? onStatusChanged;

  MouldKingClassicController(TrainConfig config) : super(config);

  @override
  void setLight(String port, bool isOn) {
    // Port C bleibt manuell schaltbar
    if (port == 'C') lightC = isOn ? 100 : 0;
    
    // Falls autoLight aus ist, kann man B auch manuell schalten
    if (!config.autoLight && port == 'B') lightB = isOn ? 100 : 0;
    
    onStatusChanged?.call();
  }

  @override
  void updateAutoLight() {
    // Wird aufgerufen, wenn sich die Richtung (lastDirForward) ändert
  }

  Future<void> _broadcast(Uint8List payload) async {
    try {
      await platform.invokeMethod('startDinoAdvertising', { 'payload': payload });
    } on PlatformException catch (e) {
      debugPrint("Native Fehler: ${e.message}");
    }
  }

  @override
  Future<void> connectAndInitialize() async {
    isRunning = true;
    _actualSpeed = 0.0; 
    targetSpeed = 0.0;
    onStatusChanged?.call();

    await _broadcast(MouldKing40Protocol.getHandshake());
    await Future.delayed(const Duration(milliseconds: 600));
    senderLoop(); 
  }

  @override
  Future<void> senderLoop() async {
    while (isRunning) {
      final double target = targetSpeed; 
      final double step = config.rampStep; 

      // --- RAMPING ---
      if (_actualSpeed < target) {
        _actualSpeed += step;
        if (_actualSpeed > target) _actualSpeed = target;
      } else if (_actualSpeed > target) {
        _actualSpeed -= step;
        if (_actualSpeed < target) _actualSpeed = target;
      }

      // --- PORT LOGIK ---
      
      // Port A: Hauptmotor
      int pA = _actualSpeed.round();
      
      // Port D: Zweiter Motor (Invertiert zu A)
      int pD = -pA; 

      // Port B: Fahrtabhängiges Licht
      // Wenn autoLight an ist, bestimmt die Richtung die Polarität
      int pB = 0;
      if (config.autoLight) {
        if (_actualSpeed > 0.5) pB = 100;       // Vorwärts: Volle Kraft positiv
        else if (_actualSpeed < -0.5) pB = -100; // Rückwärts: Volle Kraft negativ
        else pB = 0;                             // Stand: Licht aus
      } else {
        pB = lightB; // Manueller Modus
      }

      // Port C: Statisches Licht (manuell)
      int pC = lightC;

      // Senden an das 4-Kanal-Protokoll
      final payload = MouldKing40Protocol.getDrive(pA, pB, pC, pD);
      await _broadcast(payload);
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void emergencyStop() {
    _actualSpeed = 0.0;
    targetSpeed = 0.0;
    // Alles auf 0 für den sofortigen Halt
    final payload = MouldKing40Protocol.getDrive(0, 0, lightC, 0);
    _broadcast(payload);
    onStatusChanged?.call();
  }

  @override
  void stop() {
    isRunning = false;
    onStatusChanged?.call();
  }
}
