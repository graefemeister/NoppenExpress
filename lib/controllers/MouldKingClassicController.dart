import 'train_controller.dart';
import 'dart:typed_data';           
import 'package:flutter/services.dart'; 
import 'package:flutter/foundation.dart';
import '../mould_king_40_protocol.dart'; 
import 'dart:async';

class MouldKingClassicController extends TrainController {
  static const platform = MethodChannel('com.noppenexpress/ble_native');

  MouldKingClassicController(super.config);

  @override
  void setLight(String port, bool isOn) {
    if (port == 'C') lightC = isOn ? 100 : 0;
    if (!config.autoLight && port == 'B') lightB = isOn ? 100 : 0;
    onStatusChanged?.call();
  }

  @override
  void updateAutoLight() {
    // Wird von der Basisklasse aufgerufen, wenn sich die Richtung ändert.
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
    currentSpeed = 0.0; 
    targetSpeed = 0.0;
    onStatusChanged?.call();

    await _broadcast(MouldKing40Protocol.getHandshake());
    await Future.delayed(const Duration(milliseconds: 600));
    senderLoop(); 
  }

  // --- DIE HARDWARE-METHODE DER BASISKLASSE ---
  @override
  void sendHardwareCommand() {
    // BLE Flood Protection:
    // Da wir per Broadcast funken, dürfen wir den Chip nicht bei 
    // jedem 10ms-Ramping-Schritt mit Befehlen fluten! 
    // Das Senden übernimmt exklusiv unsere senderLoop im 100ms-Takt.
  }

  // --- DIE NEUE, "DUMME" SENDER-LOOP ---
  @override
  Future<void> senderLoop() async {
    while (isRunning) {
      // KEINE MATHEMATIK MEHR HIER!
      // Wir lesen einfach die von der Basisklasse vorbereitete 'currentSpeed' aus.

      // Port A: Hauptmotor
      int pA = currentSpeed.round();
      
      // Port D: Zweiter Motor (Invertiert zu A)
      int pD = -pA; 

      // Port B: Fahrtabhängiges Licht
      int pB = 0;
      if (config.autoLight) {
        if (currentSpeed > 0.5) pB = 100;       // Vorwärts
        else if (currentSpeed < -0.5) pB = -100; // Rückwärts
        else pB = 0;                             // Stand
      } else {
        pB = lightB; // Manueller Modus
      }

      // Port C: Statisches Licht (manuell)
      int pC = lightC;

      // Werte in Payload verpacken und funken
      final payload = MouldKing40Protocol.getDrive(pA, pB, pC, pD);
      await _broadcast(payload);
      
      // Der rettende 100ms Heartbeat
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // --- SOFORTIGE REAKTION BEI NOTSTOPP ---
  @override
  void emergencyStop() {
    // Setzt in der Basisklasse alle Ziele auf 0 und stoppt den Timer
    super.emergencyStop(); 
    
    // Wir feuern ZUSÄTZLICH sofort einen Halt-Befehl raus, 
    // damit wir nicht auf die nächsten 100ms der Loop warten müssen!
    final payload = MouldKing40Protocol.getDrive(0, 0, lightC, 0);
    _broadcast(payload);
  }

  // --- SAUBERES TRENNEN ---
  @override
  Future<void> disconnect() async {
    // Setzt isRunning = false (stoppt senderLoop) und killt Timer
    await super.disconnect(); 
    
    // Einen letzten Halt-Befehl senden, damit der Zug nicht weiterfährt
    final payload = MouldKing40Protocol.getDrive(0, 0, lightC, 0);
    await _broadcast(payload);
  }
}