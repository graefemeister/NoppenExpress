import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'dart:async';
import 'train_controller.dart';

class BuWizz2Controller extends TrainController {
  BuWizz2Controller(super.config);

  // Die exakten UUIDs aus dem Hardware-Log
  static const String _serviceUuid = "4e050000-74fb-4481-88b3-9919b1676e93";
  static const String _charMotorUuid = "92d1";

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

    // MTU-Check
    try {
      if (await device!.mtu.first < 23) {
        await device!.requestMtu(23);
      }
    } catch (_) {}

    List<BluetoothService> services = await device!.discoverServices();
    await Future.delayed(const Duration(milliseconds: 200)); 
    
    for (var service in services) {
      // Wir suchen exakt den Service aus deinem Log
      if (service.uuid.toString().toLowerCase() == _serviceUuid) {
        for (var char in service.characteristics) {
          // Wir nutzen .contains(), da Flutter die UUID im Log verkürzt ("92d1") darstellt
          if (char.uuid.toString().toLowerCase().contains(_charMotorUuid)) {
            writeCharacteristic = char;
          }
        }
      }
    }

    if (writeCharacteristic != null) {
      try {
        // --- HIER WAR DER FEHLER: ---
        // Vorher stand hier fest: [0x11, 0x01]
        // Jetzt lesen wir dynamisch den Modus aus der gespeicherten Config:
        int selectedMode = config.buWizzPowerMode;
        
        debugPrint("BuWizz wird initialisiert im Modus: $selectedMode");

        // AKTIVIERUNG: Sende den aus dem Workshop geladenen Modus an die Hardware
        await writeCharacteristic!.write([0x11, selectedMode], withoutResponse: false); 
        
        await Future.delayed(const Duration(milliseconds: 200));

        // Erster Watchdog-Trigger (0x10 = Motor-Command)
        await writeCharacteristic!.write([0x10, 0x00, 0x00, 0x00, 0x00], withoutResponse: true);

        isRunning = true;
        onStatusChanged?.call();
        senderLoop();
      } catch (e) {
        debugPrint("Fehler bei BuWizz Aktivierung: $e");
      }
    }
  }

  // Skalierung auf den BuWizz-Bereich (-127 bis 127)
  int _scalePower(int power) {
    if (power == 0) return 0;
    double scaled = (power.abs() / 100.0) * 127;
    int result = scaled.toInt().clamp(0, 127);
    return power < 0 ? -result : result;
  }

  @override
  void sendHardwareCommand() {}

  @override
  Future<void> senderLoop() async {
    while (isRunning && writeCharacteristic != null) {
      
      int getAdjustedPower(String port) {
        String role = config.portSettings[port] ?? 'none';
        
        if (!isLightOn) {
          if (role == 'light_dir' || role == 'light_front' || role == 'light_back') return 0;
        }

        if (role == 'light_dir') {
          // Die schonende Umpolung (funktioniert auch beim BuWizz super)
          return lastDirForward ? 100 : -10; 
        }

        return getPowerForRole(role);
      }

      int p1 = _scalePower(getAdjustedPower('A'));
      int p2 = _scalePower(getAdjustedPower('B'));
      int p3 = _scalePower(getAdjustedPower('C'));
      int p4 = _scalePower(getAdjustedPower('D'));

      // Protokoll: 0x10 (Motorbefehl) + 4 signierte Bytes
      List<int> packet = [
        0x10, 
        p1 < 0 ? 256 + p1 : p1,
        p2 < 0 ? 256 + p2 : p2,
        p3 < 0 ? 256 + p3 : p3,
        p4 < 0 ? 256 + p4 : p4,
      ];

      try {
        await writeCharacteristic!.write(packet, withoutResponse: true);
      } catch (e) {
        break;
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}