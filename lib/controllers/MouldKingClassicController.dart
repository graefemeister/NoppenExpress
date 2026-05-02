import 'train_controller.dart';
import 'dart:typed_data';           
import 'package:flutter/services.dart'; 
import 'package:flutter/foundation.dart';
import '../mould_king_40_protocol.dart'; 
import 'dart:async';
import 'mould_king_central.dart';

class MouldKingClassicController extends TrainController {
  static const platform = MethodChannel('com.noppenexpress/ble_native');

  // Holt den ausgewählten Kanal (1, 2 oder 3) aus dem Workshop
  int get mkChannel => config.channel ?? 1; 

  MouldKingClassicController(super.config);

  @override
  void setLight(String port, bool isOn) {
    if (port == 'C') lightC = isOn ? 100 : 0;
    if (port == 'B') lightB = isOn ? 100 : 0;
    onStatusChanged?.call();
  }

  @override
  Future<void> connectAndInitialize() async {
    isRunning = true;
    currentSpeed = 0.0; 
    targetSpeed = 0.0;
    onStatusChanged?.call();

    // Wir rufen den Handshake für DIESEN Controller auf (optional)
    await platform.invokeMethod('startMouldKingBroadcast', { 
        'payload': MouldKing40Protocol.getHandshake() 
    });
    await Future.delayed(const Duration(milliseconds: 600));
    
    // Startet die zentrale Funke (passiert nur beim ersten MK-Controller)
    MouldKingCentral.startLoop(platform);

    // Startet die Logik-Schleife für DIESEN spezifischen Controller
    logicLoop(); 
  }

  // Das war früher die senderLoop. Jetzt funkt sie nicht mehr, 
  // sondern macht nur noch reine Mathematik.
  Future<void> logicLoop() async {
    while (isRunning) {
      // --- 1. MOTOR & INVERTIERUNG ---
      int pA = currentSpeed.round();
      if (config.inverted) pA = -pA;
      int pD = -pA;

      // --- 2. LICHT ---
      int pB = 0;
      if (lightB != 0) {
        pB = config.autoLight ? (lastDirForward ? 100 : -100) : lightB;
        if (config.autoLight && config.inverted) pB = -pB;
      }
      int pC = lightC;

      // --- 3. STATE UPDATEN (Statt selbst zu funken!) ---
      MouldKingCentral.updateState(mkChannel, pA, pB, pC, pD);

      // Hier können wir sogar schneller loopen (z.B. 50ms) für sanfteres 
      // UI-Ramping, da die zentrale Funke stur bei 70ms bleibt!
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  void emergencyStop() {
    super.emergencyStop(); 
    MouldKingCentral.updateState(mkChannel, 0, 0, lightC, 0);
  }

  @override
  Future<void> disconnect() async {
    await super.disconnect(); 
    // Lok-Werte auf 0 setzen beim Disconnect
    MouldKingCentral.updateState(mkChannel, 0, 0, 0, 0);
  }

  @override
  void sendHardwareCommand() {}

  @override
  Future<void> senderLoop() async {}

  @override
  void updateAutoLight() {}
}