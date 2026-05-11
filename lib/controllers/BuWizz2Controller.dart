import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'train_controller.dart';

class BuWizz2Controller extends TrainController {
  // Die Basis-Kennung für BuWizz 2.0 Revisionen
  static const String buwizzPrefix = "4e05"; 

  BuWizz2Controller(super.config);

  @override
  Future<void> connectAndInitialize() async {
    if (isRunning) return;

    debugPrint("BuWizz 2.0: Starte Deep-Scan für Hardware-Revision 4e05...");
    device = BluetoothDevice.fromId(config.mac);

    try {
      await device!.connect(timeout: const Duration(seconds: 5), autoConnect: false);
      List<BluetoothService> services = await device!.discoverServices();
      
      for (var service in services) {
        String sUuid = service.uuid.toString().toLowerCase();
        
        // Wir prüfen alle Services, die mit 4e05 beginnen
        if (sUuid.startsWith(buwizzPrefix)) {
          debugPrint("BuWizz Service gefunden: $sUuid");
          
          for (var char in service.characteristics) {
            String cUuid = char.uuid.toString().toLowerCase();
            debugPrint("  Prüfe Charakteristik: $cUuid");

            // SMART-MATCH: Wir nehmen die Charakteristik, die Schreiben ohne Antwort erlaubt
            // Das ist bei BuWizz fast immer der Steuerkanal.
            if (char.properties.writeWithoutResponse || char.properties.write) {
              writeCharacteristic = char;
              debugPrint(">>> SMART-MATCH ERFOLGREICH: Nutze $cUuid zum Steuern!");
              break; 
            }
          }
        }
        if (writeCharacteristic != null) break;
      }

      if (writeCharacteristic != null) {
        isRunning = true;
        if (onStatusChanged != null) onStatusChanged!(); 
        senderLoop(); // Startet den Heartbeat[cite: 4]
      } else {
        debugPrint("FEHLER: Kein schreibbarer Kanal in den BuWizz-Services gefunden.");
        await device!.disconnect();
      }
    } catch (e) {
      debugPrint("BuWizz 2.0 Deep-Scan Fehler: $e");
      isRunning = false;
      onStatusChanged?.call();
    }
  }

  @override
  void sendHardwareCommand() {}

  @override
  Future<void> senderLoop() async {
    while (isRunning && writeCharacteristic != null) {
      try {
        // Nutzt die dynamische Port-Konfiguration[cite: 6]
        int pA = _scale(getPowerForRole(config.portSettings['A'] ?? 'none'));
        int pB = _scale(getPowerForRole(config.portSettings['B'] ?? 'none'));
        int pC = _scale(getPowerForRole(config.portSettings['C'] ?? 'none'));
        int pD = _scale(getPowerForRole(config.portSettings['D'] ?? 'none'));

        // BuWizz 2.0 Protokoll: [0x10, A, B, C, D, 0x00]
        final List<int> data = [0x10, pA.toSigned(8), pB.toSigned(8), pC.toSigned(8), pD.toSigned(8), 0x00];
        
        await writeCharacteristic!.write(data, withoutResponse: true);
      } catch (e) {
        debugPrint("BuWizz 2.0: Verbindung im Loop verloren: $e");
        isRunning = false;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100)); // Heartbeat alle 100ms[cite: 4]
    }
    onStatusChanged?.call(); // UI-Update bei Verbindungsverlust[cite: 2]
  }

  int _scale(int percent) => (percent * 1.27).round().clamp(-127, 127);

  @override
  Future<void> disconnect() async {
    isRunning = false;
    await super.disconnect();
  }
}