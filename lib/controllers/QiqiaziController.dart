import 'train_controller.dart';
import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 

class QiqiaziController extends TrainController {
  QiqiaziController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    debugPrint("Qiqiazi: Starte Verbindung zu ${config.mac}...");
    device = BluetoothDevice.fromId(config.mac);

    device!.connectionState.listen((state) {
      debugPrint("Qiqiazi: Verbindungsstatus geändert: $state");
      if (state == BluetoothConnectionState.disconnected && isRunning) {
        isRunning = false;
        onStatusChanged?.call();
      }
    });

    try {
      await device!.connect().catchError((e) => debugPrint("Qiqiazi: Connect Hinweis: $e")); 
      await Future.delayed(const Duration(milliseconds: 500));
      
      debugPrint("Qiqiazi: Suche Services...");
      List<BluetoothService> services = await device!.discoverServices();
      
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase().contains("fff2")) {
            writeCharacteristic = characteristic;
            debugPrint("Qiqiazi: Schreib-Charakteristik gefunden: ${characteristic.uuid}");
          }
        }
      }

      if (writeCharacteristic != null) {
        isRunning = true;
        debugPrint("Qiqiazi: isRunning ist jetzt TRUE. Melde Status an UI...");
        onStatusChanged?.call();
        
        // Initialer Stopp-Befehl
        await _sendRaw(0, 0, 0, 0);
        
        senderLoop();
      } else {
        debugPrint("Qiqiazi: FEHLER - FFF2 Charakteristik nicht gefunden!");
      }
    } catch (e) {
      debugPrint("Qiqiazi: Schwerer Fehler bei Initialisierung: $e");
      isRunning = false;
      onStatusChanged?.call();
    }
  }

  // --- DIE HARDWARE-METHODE DER BASISKLASSE ---
  @override
  void sendHardwareCommand() {
    // BLE Flood Protection:
    // Der Qiqiazi braucht einen regelmäßigen Heartbeat. Wir lassen 
    // das Senden komplett in der senderLoop, damit wir den BLE-Chip 
    // nicht durch zu schnelle Ramping-Timer-Aufrufe überlasten.
  }

  // --- DIE INTELLIGENTE SENDER-LOOP ---
  @override
  Future<void> senderLoop() async {
    debugPrint("Qiqiazi: SenderLoop gestartet");
    while (isRunning && writeCharacteristic != null) {
      
      // 1. Hole dynamisch die Power (-100 bis +100) für alle 4 Ports
      int pA = getPowerForRole(config.portSettings['A'] ?? 'none');
      int pB = getPowerForRole(config.portSettings['B'] ?? 'none');
      int pC = getPowerForRole(config.portSettings['C'] ?? 'none');
      int pD = getPowerForRole(config.portSettings['D'] ?? 'none');

      int b5 = 0; int b6 = 0; int b7 = 0; int b8 = 0;

      // --- SLOT 1: Physischer Port A (Motor) & Port B (Licht) ---
      if (pA > 0) b5 |= 1;
      if (pA < 0) b5 |= 2;
      if (pB != 0) b5 |= 4; 

      int absA = (pA.abs() * 2.55).toInt().clamp(0, 255);
      int absB = (pB.abs() * 2.55).toInt().clamp(0, 255);
      
      // Hardware-Limit: A und B teilen sich das Geschwindigkeits-Byte! Der höhere Wert gewinnt.
      b6 = (absA > absB) ? absA : absB; 
      if ((b5 & 4) != 0 && b6 == 0) b6 = 255; // Licht leuchtet, aber Motor steht -> volles PWM!

      // --- SLOT 2: Physischer Port C (Licht) & Port D (Motor) ---
      if (pC != 0) b7 |= 1;
      if (pD > 0) b7 |= 8;
      if (pD < 0) b7 |= 4;

      int absC = (pC.abs() * 2.55).toInt().clamp(0, 255);
      int absD = (pD.abs() * 2.55).toInt().clamp(0, 255);
      
      // Hardware-Limit: C und D teilen sich das Geschwindigkeits-Byte!
      b8 = (absC > absD) ? absC : absD; 
      if ((b7 & 1) != 0 && b8 == 0) b8 = 255; // Licht leuchtet, aber Motor steht -> volles PWM!

      await _sendRaw(b5, b6, b7, b8);
      
      // Fester 100ms Heartbeat
      await Future.delayed(const Duration(milliseconds: 100));
    }
    debugPrint("Qiqiazi: SenderLoop beendet");
  }

  Future<void> _sendRaw(int b5, int b6, int b7, int b8) async {
    if (writeCharacteristic == null) return;
    
    List<int> cmd = [0x5A, 0x6B, 0x02, 0x00, 0x05, b5, b6, b7, b8, 0x01, 0x00];
    int sum = 0;
    for (int i = 0; i <= 9; i++) sum += cmd[i];
    cmd[10] = sum & 0xFF;

    try {
      await writeCharacteristic!.write(cmd, withoutResponse: false);
    } catch (e) {
      debugPrint("Qiqiazi: Schreibfehler: $e");
      isRunning = false;
      onStatusChanged?.call();
    }
  }

  @override
  void emergencyStop() {
    super.emergencyStop(); 
    _sendRaw(0, 0, 0, 0);  // Sicherheitshalber sofort funken, um das 100ms Delay zu umgehen
  }

  @override
  Future<void> disconnect() async {
    // WICHTIG: Erst das Stop-Kommando senden, SOLANGE Bluetooth noch verbunden ist!
    await _sendRaw(0, 0, 0, 0); 
    await super.disconnect(); // Danach erst in der Basisklasse die Verbindung kappen
  }
}