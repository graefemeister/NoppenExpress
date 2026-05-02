import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../mould_king_40_protocol.dart';

class MouldKingCentral {
  static bool isBroadcasting = false;
  
  // Speichert die aktuellen Werte für [pA, pB, pC, pD] für Kanal 1, 2 und 3
  static Map<int, List<int>> states = {
    1: [0, 0, 0, 0],
    2: [0, 0, 0, 0],
    3: [0, 0, 0, 0],
  };

  // Wird von den einzelnen Controllern aufgerufen
  static void updateState(int channel, int pA, int pB, int pC, int pD) {
    states[channel] = [pA, pB, pC, pD];
  }

  // Die EINE wahre Sende-Schleife
  static Future<void> startLoop(MethodChannel platform) async {
    if (isBroadcasting) return; // Läuft schon? Dann nichts tun!
    isBroadcasting = true;

    while (isBroadcasting) {
      // Holt das Unified Packet mit ALLEN 3 Kanälen aus dem Protocol
      final payload = MouldKing40Protocol.getUnifiedDrive(
        states[1]!, states[2]!, states[3]!
      );

      try {
        await platform.invokeMethod('startMouldKingBroadcast', {
          'payload': payload,
          'companyId': 0x4B4D,
        });
      } catch (e) {
        debugPrint("Native Fehler: $e");
      }

      // 70ms Puffer für flüssiges Ramping aller drei Loks
      await Future.delayed(const Duration(milliseconds: 70));
    }
  }
}