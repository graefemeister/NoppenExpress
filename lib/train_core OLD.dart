import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// --- DIE DATEN-KLASSE (Der "Ausweis" der Lok) ---
class TrainConfig {
  String id; // Eindeutige ID (meistens die MAC)
  String name;
  String mac;
  String imagePath;
  String protocol; // 'mould_king' oder 'circuit_cube'
  Map<int, double> gears;
  double rampStep;
  double reverseLimit;
  String notes;

  TrainConfig({
    required this.id,
    required this.name,
    required this.mac,
    required this.imagePath,
    required this.protocol,
    required this.gears,
    this.rampStep = 1.0,
    this.reverseLimit = 1.0,
    this.notes = "",
  });

  // Verwandelt die Lok in Text (JSON) zum Speichern
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mac': mac,
      'imagePath': imagePath,
      'protocol': protocol,
      'gears': gears.map((k, v) => MapEntry(k.toString(), v)),
      'rampStep': rampStep,
      'reverseLimit': reverseLimit,
      'notes': notes,
    };
  }

  // Erstellt eine Lok aus gespeichertem Text (JSON)
  factory TrainConfig.fromMap(Map<String, dynamic> map) {
    return TrainConfig(
      id: map['id'],
      name: map['name'],
      mac: map['mac'],
      imagePath: map['imagePath'],
      protocol: map['protocol'],
      gears: (map['gears'] as Map).map((k, v) => MapEntry(int.parse(k), v.toDouble())),
      rampStep: map['rampStep']?.toDouble() ?? 1.0,
      reverseLimit: map['reverseLimit']?.toDouble() ?? 1.0,
      notes: map['notes'] ?? "",
    );
  }
}

// --- DIE LOGIK-KLASSE (Die Hardware-Steuerung) ---
abstract class TrainController {
  final TrainConfig config; // Hält alle Daten
  
  bool inverted = false;
  bool isRunning = false;
  double targetSpeed = 0.0;
  double currentSpeed = 0.0;
  int lightB = 0;
  int lightC = 0;

  BluetoothDevice? device;
  BluetoothCharacteristic? writeCharacteristic;

  TrainController(this.config);

  // Hilfsmethoden, die auf die Config zugreifen
  String get name => config.name;
  String get mac => config.mac;
  String get imagePath => config.imagePath;

  void toggleInverted() {
    inverted = !inverted;
    print("🔄 $name: Invertierung ist jetzt ${inverted ? 'AKTIV' : 'AUS'}.");
  }

  void setGear(int gearNumber, {bool forward = true}) {
    bool actualForward = inverted ? !forward : forward;
    if (config.gears.containsKey(gearNumber)) {
      double speed = config.gears[gearNumber]!;
      if (!actualForward && config.reverseLimit < 1.0) speed *= config.reverseLimit;
      targetSpeed = actualForward ? speed : -speed;
    }
  }

  void emergencyStop() {
    targetSpeed = 0.0;
    currentSpeed = 0.0;
  }

  void setLight(String port, bool isOn) {
    int val = isOn ? 100 : 0;
    if (port.toUpperCase() == 'B') lightB = val;
    if (port.toUpperCase() == 'C') lightC = val;
  }

  Future<void> disconnect() async {
    isRunning = false;
    await Future.delayed(const Duration(milliseconds: 200));
    if (device != null) {
      try { await device!.disconnect(); } catch (e) { print("⚠️ Fehler beim Trennen: $e"); }
    }
  }

  Future<void> connectAndInitialize();
  Future<void> senderLoop();
}

// --- DIE SPEZIFISCHEN PROTOKOLLE ---

class MouldKingController extends TrainController {
  final String charUuid = "0000ae3b-0000-1000-8000-00805f9b34fb";
  MouldKingController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    device = BluetoothDevice.fromId(config.mac);
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
      senderLoop();
    }
  }

  String _pctToHex(double pct) {
    if (pct == 0) return "0000";
    int val = (pct.abs() / 100.0 * 32767).toInt();
    if (pct < 0) val += 0x8000;
    return val.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  @override
  Future<void> senderLoop() async {
    isRunning = true;
    while (isRunning && writeCharacteristic != null) {
      double step = (targetSpeed.abs() > currentSpeed.abs()) ? config.rampStep : 3.0;
      if (currentSpeed == 0 && targetSpeed != 0) currentSpeed = targetSpeed > 0 ? 20.0 : -20.0;
      
      if (currentSpeed < targetSpeed) {
        currentSpeed = (currentSpeed + step > targetSpeed) ? targetSpeed : currentSpeed + step;
      } else if (currentSpeed > targetSpeed) {
        currentSpeed = (currentSpeed - step < targetSpeed) ? targetSpeed : currentSpeed - step;
      }

      String hexA = _pctToHex(currentSpeed);
      String hexD = currentSpeed != 0 ? _pctToHex(-currentSpeed) : "0000";
      String hexB = _pctToHex(lightB.toDouble());
      String hexC = _pctToHex(lightC.toDouble());
      String cmdStr = "T1440${hexA}${hexB}${hexC}000${hexD}W";
      
      try {
        await writeCharacteristic!.write([0x01], withoutResponse: true);
        await writeCharacteristic!.write(utf8.encode(cmdStr), withoutResponse: true);
      } catch (e) { break; }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}

class CircuitCubeController extends TrainController {
  final String charUuid = "00001524-0000-1000-8000-00805f9b34fb";
  CircuitCubeController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    device = BluetoothDevice.fromId(config.mac);
    await device!.connect();
    List<BluetoothService> services = await device!.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString().toLowerCase() == charUuid) {
          writeCharacteristic = characteristic;
        }
      }
    }
    if (writeCharacteristic != null) senderLoop();
  }

  @override
  Future<void> senderLoop() async {
    isRunning = true;
    while (isRunning && writeCharacteristic != null) {
      String direction = targetSpeed >= 0 ? "+" : "-";
      int speed = (targetSpeed.abs() * 2.55).toInt();
      String cmd = "$direction${speed.toString().padLeft(3, '0')}a";
      try {
        await writeCharacteristic!.write(utf8.encode(cmd), withoutResponse: true);
      } catch (e) { break; }
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }
}