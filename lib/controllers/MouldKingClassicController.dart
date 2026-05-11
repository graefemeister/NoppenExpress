import 'dart:async';
import 'dart:typed_data'; // WICHTIG
import 'package:flutter/services.dart';
import 'train_controller.dart';
import 'mould_king_central.dart'; 
import '../mould_king_40_protocol.dart';

class MouldKingClassicController extends TrainController {
  static const platform = MethodChannel('com.noppenexpress/ble_native'); 

  MouldKingClassicController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    isRunning = true;
    onStatusChanged?.call();
    
    final handshake = MouldKing40Protocol.getHandshake();
    await platform.invokeMethod('startMouldKingBroadcast', { 
        'payload': Uint8List.fromList(handshake) 
    });
    
    // Kurze Pause, damit die Box bereit ist
    await Future.delayed(const Duration(milliseconds: 500));

    // Startet die zentrale Funke
    MouldKingCentral.startLoop(platform);
  }

  @override
  void sendHardwareCommand() {
    if (!isRunning) return;

    int powerA = getPowerForRole(config.portSettings['A'] ?? 'none');
    int powerB = getPowerForRole(config.portSettings['B'] ?? 'none');
    int powerC = getPowerForRole(config.portSettings['C'] ?? 'none');
    int powerD = getPowerForRole(config.portSettings['D'] ?? 'none');

    MouldKingCentral.updateState(
      config.channel ?? 1, 
      powerA, powerB, powerC, powerD
    );
  }

  @override
  Future<void> senderLoop() async {
    // Bleibt leer, da MouldKingCentral die Arbeit macht
  }

  @override
  Future<void> disconnect() async {
    isRunning = false;
    MouldKingCentral.updateState(config.channel ?? 1, 0, 0, 0, 0);
    await super.disconnect(); 
  }
}