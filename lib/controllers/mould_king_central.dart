import 'dart:typed_data'; // WICHTIG für Uint8List
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../mould_king_40_protocol.dart';

class MouldKingCentral {
  static bool isBroadcasting = false;
  
  static Map<int, List<int>> states = {
    1: [0, 0, 0, 0],
    2: [0, 0, 0, 0],
    3: [0, 0, 0, 0],
  };

  static void updateState(int channel, int pA, int pB, int pC, int pD) {
    states[channel] = [pA, pB, pC, pD];
  }

  // Die EINE wahre Sende-Schleife
  static Future<void> startLoop(MethodChannel platform) async {
    if (isBroadcasting) return; 
    isBroadcasting = true;

    while (isBroadcasting) {
      // Holt das Unified Packet mit ALLEN 3 Kanälen
      final List<int> combinedData = MouldKing40Protocol.getUnifiedDrive(
        states[1]!, states[2]!, states[3]!
      );

      try {

        await platform.invokeMethod('startMouldKingBroadcast', {
          'payload': Uint8List.fromList(combinedData),
          'companyId': 0x4B4D,
        });
      } catch (e) {
        debugPrint("Native Fehler in Central Loop: $e");
      }

      await Future.delayed(const Duration(milliseconds: 70));
    }
  }
}