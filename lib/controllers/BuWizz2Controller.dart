import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'train_controller.dart';

class BuWizz2Controller extends TrainController {
  BuWizz2Controller(super.config);

  // Die exakten UUIDs aus dem Hardware-Log
  static const String _serviceUuid = "4e050000-74fb-4481-88b3-9919b1676e93";
  static const String _charMotorUuid = "92d1";

  double? _filteredVoltage;
  DateTime _lastBatteryUpdate = DateTime.fromMillisecondsSinceEpoch(0);

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
        // Dynamisch den Modus aus der gespeicherten Config lesen
        int selectedMode = config.buWizzPowerMode;

        debugPrint("BuWizz wird initialisiert im Modus: $selectedMode");

        // AKTIVIERUNG: Sende den aus dem Workshop geladenen Modus an die Hardware
        await writeCharacteristic!.write([
          0x11,
          selectedMode,
        ], withoutResponse: false);

        await Future.delayed(const Duration(milliseconds: 200));

        // Erster Watchdog-Trigger (0x10 = Motor-Command)
        await writeCharacteristic!.write([
          0x10,
          0x00,
          0x00,
          0x00,
          0x00,
        ], withoutResponse: true);

        // TELEMETRIE: Status Notifications auf writeCharacteristic (0x92d1) aktivieren
        try {
          await writeCharacteristic!.setNotifyValue(true);
          writeCharacteristic!.onValueReceived.listen((data) {
            // BuWizz 2.0 Device Status Report: Byte 0 ist 0x00, Byte 2 ist Battery Voltage
            // Formel: 3.0V + (data[2] * 0.01V)
            if (data.length >= 8 && data[0] == 0x00 && data[2] > 0) {
              double rawVoltage = 3.0 + (data[2] * 0.01);

              // 1. Tiefpassfilter (Glättung): Filtert kurzzeitige Spannungseinbrüche & ADC-Rauschen (25 Hz)
              _filteredVoltage = _filteredVoltage == null
                  ? rawVoltage
                  : (_filteredVoltage! * 0.95 + rawVoltage * 0.05);

              // 2. Drosselung: Aktualisiert das UI maximal alle 3 Sekunden (beim 1. Mal sofort)
              final now = DateTime.now();
              if (batteryLevel == null ||
                  now.difference(_lastBatteryUpdate).inSeconds >= 3) {
                _lastBatteryUpdate = now;

                // LiPo-Kennlinie 1S: 3.3V = 0% bis 4.2V = 100%
                double pct = ((_filteredVoltage! - 3.3) / (4.2 - 3.3)) * 100.0;
                int newLevel = pct.round().clamp(0, 100);

                if (newLevel != batteryLevel) {
                  batteryLevel = newLevel;
                  onStatusChanged?.call();
                }
              }
            }
          });
        } catch (e) {
          debugPrint("BuWizz2 Battery Telemetrie Fehler: $e");
        }

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

        int power = getPowerForRole(role, port);
        if (power == 0) {
          return 0;
        }

        if (role == 'light_dir') {
          // Die schonende Umpolung (funktioniert auch beim BuWizz super)
          return lastDirForward ? power.abs() : -10;
        }

        if (role == 'light_dir_inv') {
          // Die schonende Umpolung (funktioniert auch beim BuWizz super)
          return lastDirForward ? -10 : power.abs();
        }

        return power;
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

  @override
  Future<void> disconnect() async {
    _filteredVoltage = null;
    _lastBatteryUpdate = DateTime.fromMillisecondsSinceEpoch(0);
    await super.disconnect();
  }
}
