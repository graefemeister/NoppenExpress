import 'package:flutter/foundation.dart';               
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'train_controller.dart';
import 'dart:async';

class LegoHubController extends TrainController {
  final String serviceUuid = "00001623-1212-efde-1623-785feabcd123";
  final String charUuid = "00001624-1212-efde-1623-785feabcd123";

  LegoHubController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    device = BluetoothDevice.fromId(config.mac);

    device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && isRunning) {
        isRunning = false;
        onStatusChanged?.call();
      }
    });

    try {
      // 1. Sanfter Start: Erstmal alles stoppen
      try { await FlutterBluePlus.stopScan(); } catch (_) {}
      try { await device!.disconnect(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 800));

      // 2. Verbinden ohne AutoConnect (wichtig für Android)
      await device!.connect(timeout: const Duration(seconds: 5), autoConnect: false);
      
      // 3. WICHTIG: Services entdecken, aber 2a05 ignorieren!
      List<BluetoothService> services = await device!.discoverServices(
        subscribeToServicesChanged: false 
      );
      
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == charUuid) {
              writeCharacteristic = characteristic;
            }
          }
        }
      }
      
      if (writeCharacteristic != null) {
        isRunning = true;
        onStatusChanged?.call();
        // Keine senderLoop() mehr nötig, da "On-Demand" gefunkt wird!
      } else {
        await device!.disconnect();
      }
    } catch (e) {
      debugPrint("LEGO Hub Verbindungsfehler: $e");
      isRunning = false;
      onStatusChanged?.call();
    }
  }

  // --- HILFSMETHODE FÜR DAS LEGO PROTOKOLL ---
  void _sendPortPower(int portIndex, int power) {
    if (writeCharacteristic == null || !isRunning) return;
    
    // Die Power kommt bereits fertig berechnet (-100 bis +100) aus der Basisklasse
    int finalPower = power.clamp(-100, 100);

    List<int> cmd = [
      0x08, 0x00, 0x81, portIndex, 0x11, 0x51, 0x00, finalPower.toUnsigned(8)
    ];
    writeCharacteristic!.write(cmd, withoutResponse: true);
  }

  // --- DIE HARDWARE-METHODE DER BASISKLASSE ---
  @override
  void sendHardwareCommand() {
    // Wird automatisch vom Ramping-Timer oder den Buttons aufgerufen
    if (!isRunning || writeCharacteristic == null) return;
    
    // Der LEGO PU Hub hat die physischen Ports A (0x00) und B (0x01)
    Map<String, int> hubPorts = {'A': 0x00, 'B': 0x01};

    hubPorts.forEach((portName, portIndex) {
      String role = config.portSettings[portName] ?? 'none';
      
      if (role != 'none') {
        int power = getPowerForRole(role);
        _sendPortPower(portIndex, power);
      } else {
        // Zur Sicherheit Strom wegnehmen, wenn der Port ungenutzt ist
        _sendPortPower(portIndex, 0);
      }
    });
  }

  // --- DIE ALTE SENDER-LOOP WIRD ARBEITSLOS ---
  @override
  Future<void> senderLoop() async {
    // Bleibt komplett leer, da das Lego-Protokoll keinen ständigen Heartbeat benötigt.
    // Alles läuft super effizient On-Demand!
  }
}