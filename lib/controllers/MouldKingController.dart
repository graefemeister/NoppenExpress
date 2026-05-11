import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'dart:convert';                                 
import 'train_controller.dart';

class MouldKingController extends TrainController {
  MouldKingController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    device = BluetoothDevice.fromId(config.mac);

    device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && isRunning) {
        isRunning = false;
        onStatusChanged?.call();
      }
    });

    await device!.connect(); 
    await Future.delayed(const Duration(milliseconds: 500));
    
    List<BluetoothService> services = await device!.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString().toLowerCase().contains("ae3b")) {
          writeCharacteristic = characteristic;
        }
      }
    }

    if (writeCharacteristic != null) {
      List<String> wakeupCmds = ["T041AABBW", "T00EW", "T01F1W", "T00CW"];
      for (var cmd in wakeupCmds) {
        await writeCharacteristic!.write(utf8.encode(cmd), withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      isRunning = true;
      onStatusChanged?.call();
      senderLoop(); // Wichtig: Loop starten für den Heartbeat!
    }
  }

  // --- HILFSMETHODE: WANDELT POWER (-100 BIS 100) IN DEN MK-HEX-STRING ---
  String _powerToHex(int power) {
    if (power == 0) return "0000";
    
    // Umrechnen der Prozente in den 15-Bit Integer-Bereich von Mould King
    int val = (power.abs() / 100.0 * 32767).toInt().clamp(0, 32767);
    
    // Bei Rückwärtsfahrt das Vorzeichen-Bit (0x8000) setzen
    if (power < 0) val += 0x8000;
    
    return val.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  // --- DIE HARDWARE-METHODE DER BASISKLASSE ---
  @override
  void sendHardwareCommand() {
  }

  // --- DIE INTELLIGENTE SENDER-LOOP ---
  @override
  Future<void> senderLoop() async {
    while (isRunning && writeCharacteristic != null) {
      
      int powerA = getPowerForRole(config.portSettings['A'] ?? 'none');
      int powerB = getPowerForRole(config.portSettings['B'] ?? 'none');
      int powerC = getPowerForRole(config.portSettings['C'] ?? 'none');
      int powerD = getPowerForRole(config.portSettings['D'] ?? 'none');
      int powerE = getPowerForRole(config.portSettings['E'] ?? 'none');
      int powerF = getPowerForRole(config.portSettings['F'] ?? 'none');

      String hexA = _powerToHex(powerA);
      String hexB = _powerToHex(powerB);
      String hexC = _powerToHex(powerC);
      String hexD = _powerToHex(powerD);
      
      // Prüfen, ob Ports E oder F im Workshop belegt wurden
      bool is6PortHub = config.portSettings.containsKey('E') || config.portSettings.containsKey('F');

      String cmdStr;
      
      if (is6PortHub) {
        // Die lange Version für die 6-Port Akkubox (30 Zeichen)
        String hexE = _powerToHex(powerE);
        String hexF = _powerToHex(powerF);
        cmdStr = "T1440${hexA}${hexB}${hexC}${hexD}${hexE}${hexF}W";
      } else {
        // Die exakte, bewährte Legacy-Version für die 4-Port Akkubox (25 Zeichen)
        // WICHTIG: Die "000" bleiben genau so erhalten, wie in deinem Original-Code!
        cmdStr = "T1440${hexA}${hexB}${hexC}000${hexD}W";
      }
      
      try {
        await writeCharacteristic!.write([0x01], withoutResponse: true);
        await writeCharacteristic!.write(utf8.encode(cmdStr), withoutResponse: true);
      } catch (e) { 
        break; 
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}