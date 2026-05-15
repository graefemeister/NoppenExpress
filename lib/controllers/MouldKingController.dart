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
      senderLoop(); 
    }
  }

  String _powerToHex(int power) {
    if (power == 0) return "0000";
    int val = (power.abs() / 100.0 * 32767).toInt().clamp(0, 32767);
    if (power < 0) val += 0x8000;
    return val.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  @override
  void sendHardwareCommand() {}

  @override
  Future<void> senderLoop() async {
    while (isRunning && writeCharacteristic != null) {
      
      int getAdjustedPower(String port) {
        String role = config.portSettings[port] ?? 'none';
        
        // Licht-Logik: Aus wenn isLightOn false
        if (!isLightOn) {
          if (role == 'light_dir' || role == 'light_front' || role == 'light_back') return 0;
        }

        // Spezial-Handling für bi-polare LEDs (Umpolung)
        if (role == 'light_dir') {
          // Vorwärts volle Kraft, Rückwärts sanfter Impuls zur sicheren Umpolung
          return lastDirForward ? 100 : -2; 
        }

        return getPowerForRole(role);
      }

      String hA = _powerToHex(getAdjustedPower('A'));
      String hB = _powerToHex(getAdjustedPower('B'));
      String hC = _powerToHex(getAdjustedPower('C'));
      String hD = _powerToHex(getAdjustedPower('D'));

      bool is6PortHub = config.portSettings.containsKey('E') || config.portSettings.containsKey('F');
      String cmdStr;

      if (is6PortHub) {
        String hE = _powerToHex(getAdjustedPower('E'));
        String hF = _powerToHex(getAdjustedPower('F'));
        cmdStr = "T1440$hA$hB$hC$hD$hE$hF" + "W";
      } else {
        // Die exakte 25-Zeichen-Struktur für deinen 4-Port Hub
        cmdStr = "T1440$hA$hB$hC" + "000" + "$hD" + "W";
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