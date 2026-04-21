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
    
    // KORREKTUR: Wir haben '!config.autoLight' hier entfernt!
    // Dadurch kann der Nutzer das Licht an Port B immer über die UI 
    // ein- und ausschalten. Der Schalter bestimmt ab jetzt nur noch, 
    // OB das Licht leuchten darf. Das WIE klärt die senderLoop.
    if (port == 'B') lightB = isOn ? 100 : 0;
    
    onStatusChanged?.call();
  }

  @override
  void updateAutoLight() {
    // Wird von der Basisklasse aufgerufen. Da unsere senderLoop
    // ohnehin alle 100ms läuft, müssen wir hier nichts extra tun.
  }

  Future<void> _broadcast(Uint8List payload) async {
    try {
      await platform.invokeMethod('startMouldKingBroadcast', { 'payload': payload });
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

  @override
  void sendHardwareCommand() {
    // BLE Flood Protection (wird von senderLoop übernommen)
  }

  @override
  Future<void> senderLoop() async {
    while (isRunning) {
      // --- 1. MOTOR & INVERTIERUNG ---
      int pA = currentSpeed.round();
      if (config.inverted) pA = -pA;
      
      // Port D: Zweiter Motor (spiegelverkehrt)
      int pD = -pA;

      // --- 2. LICHT & AUTOLIGHT LOGIK ---
      int pB = 0;
      if (lightB != 0) {
        if (config.autoLight) {
          pB = lastDirForward ? 100 : -100;
          if (config.inverted) pB = -pB;
        } else {
          pB = lightB;
        }
      } else {
        pB = 0;
      }

      // Port C: Statisches Licht
      int pC = lightC;

      // --- 3. PAYLOAD GENERIEREN ---
      final payload = MouldKing40Protocol.getDrive(pA, pB, pC, pD);

      // --- 4. DER "BLITZ" (MouldKingBroadcast) ---
      // Wir rufen die umbenannte native Methode auf.
      // Durch den duration-Parameter (10ms) in Kotlin blitzt das Handy 
      // jetzt kurz auf und wechselt die MAC.
      await platform.invokeMethod('startMouldKingBroadcast', {
        'payload': payload,
        'companyId': 0x4B4D,
      });

      // --- 5. TIMING ---
      // Wir warten 70ms bis zum nächsten Blitz. 
      // Das entspricht ca. 14 Updates pro Sekunde – absolut flüssig für die Steuerung.
      await Future.delayed(const Duration(milliseconds: 70));
    }
  }

  @override
  void emergencyStop() {
    super.emergencyStop(); 
    final payload = MouldKing40Protocol.getDrive(0, 0, lightC, 0);
    _broadcast(payload);
  }

  @override
  Future<void> disconnect() async {
    await super.disconnect(); 
    final payload = MouldKing40Protocol.getDrive(0, 0, lightC, 0);
    await _broadcast(payload);
  }
}