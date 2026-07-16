import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'train_controller.dart';
// Deine nagelneue Protokoll-Datei importieren!
import '../mould_king_rwy_protocol.dart'; 

class MouldKingRwyController extends TrainController {
  bool isBroadcasting = false;
  static const platform = MethodChannel('com.noppenexpress/ble_native');

  MouldKingRwyController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    debugPrint("Starte RWY-Zug... Sende Golden Handshake!");
    isRunning = true;
    onStatusChanged?.call();

    // Handshake über das Protokoll abholen
    final Uint8List handshake = MouldKingRwyProtocol.getHandshake();

    for (int i = 0; i < 3; i++) {
      try {
        await platform.invokeMethod('startMouldKingBroadcast', {
          'companyId': 0xFFF0,
          'payload': handshake,
        });
      } catch (e) {
        debugPrint("Handshake Fehler: $e");
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // Warten auf "Zuhören-Modus"
    await Future.delayed(const Duration(milliseconds: 400));
    
    isBroadcasting = true;
    senderLoop(); 
  }

  @override
  Future<void> senderLoop() async {
    while (isBroadcasting) {
      // 1. Basisklasse berechnet in Ruhe das Ramping und die Umpolung
      int currentPower = getPowerForRole(config.portSettings['A'] ?? 'none');

      // 2. Das Protokoll liefert für genau diese Fahrstufe das verschlüsselte Paket
      Uint8List payload = MouldKingRwyProtocol.getDrive(currentPower);

      try {
        await platform.invokeMethod('startMouldKingBroadcast', {
          'companyId': 0xFFF0,
          'payload': payload,
        });
      } catch (e) {
        debugPrint("RWY Broadcast Fehler: $e");
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void sendHardwareCommand() {
    // Da wir alle 100ms die power live abgreifen, bleibt das hier leer
  }
  
  @override
  Future<void> disconnect() async {
    isRunning = false;
    isBroadcasting = false;
    onStatusChanged?.call();
    try {
      await platform.invokeMethod('stopMouldKingBroadcast');
    } catch (e) {
      debugPrint("Stop Fehler: $e");
    }
  }
}