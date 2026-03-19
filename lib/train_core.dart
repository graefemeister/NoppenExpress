import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';

// --- 1. DIE DATENSTRUKTUR ---
class TrainConfig {
  final String id;
  final String name;
  final String mac;
  final String protocol;
  final String imagePath;
  final String notes;
  final Map<int, double> gears;
  final double rampStep;
  final double reverseLimit;
  final bool autoLight;
  final Map<String, String> portSettings;

  TrainConfig({
    required this.id,
    required this.name,
    required this.mac,
    required this.protocol,
    this.imagePath = "",
    this.notes = "",
    this.gears = const {0: 0, 1: 25, 2: 50, 3: 75, 4: 100},
    this.rampStep = 1.0,
    this.reverseLimit = 1.0,
    this.autoLight = true,
    this.portSettings = const {'A': 'motor', 'B': 'motor'},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'name': name, 'mac': mac, 'protocol': protocol,
      'imagePath': imagePath, 'notes': notes,
      'gears': gears.map((k, v) => MapEntry(k.toString(), v)),
      'rampStep': rampStep, 'reverseLimit': reverseLimit,
      'autoLight': autoLight, 'portSettings': portSettings,
    };
  }

  factory TrainConfig.fromMap(Map<String, dynamic> map) {
    return TrainConfig(
      id: map['id'], name: map['name'], mac: map['mac'], protocol: map['protocol'],
      imagePath: map['imagePath'] ?? "", notes: map['notes'] ?? "",
      gears: (map['gears'] as Map).map((k, v) => MapEntry(int.parse(k), v.toDouble())),
      rampStep: (map['rampStep'] ?? 1.0).toDouble(),
      reverseLimit: (map['reverseLimit'] ?? 1.0).toDouble(),
      autoLight: map['autoLight'] ?? true,
      portSettings: Map<String, String>.from(map['portSettings'] ?? {'A': 'motor', 'B': 'motor'}),
    );
  }
}

// --- 2. DIE BASISKLASSE ---
abstract class TrainController {
  final TrainConfig config;
  bool isRunning = false;
  double currentSpeed = 0.0;
  double targetSpeed = 0.0;
  bool inverted = false;
  bool lastDirForward = true;
  int lightA = 0;
  int lightB = 0;
  int lightC = 0;

  BluetoothDevice? device;
  BluetoothCharacteristic? writeCharacteristic;
  VoidCallback? onStatusChanged;

  TrainController(this.config);

  String get name => config.name;
  String get mac => config.mac;
  String get imagePath => config.imagePath;

  void toggleInverted() { inverted = !inverted; }

  void setGear(int gear, {bool forward = true}) {
    bool actualForward = inverted ? !forward : forward;
    if (gear > 0) lastDirForward = forward;
    
    if (config.gears.containsKey(gear)) {
      double speed = config.gears[gear]!;
      if (!actualForward && config.reverseLimit < 1.0) speed *= config.reverseLimit;
      targetSpeed = actualForward ? speed : -speed;
    }
    if (config.autoLight) updateAutoLight();
  }

  void emergencyStop() { targetSpeed = 0.0; currentSpeed = 0.0; updateAutoLight(); }
  
  void setLight(String port, bool isOn);

  Future<void> disconnect() async {
    isRunning = false;
    await device?.disconnect();
    onStatusChanged?.call();
  }

  Future<void> connectAndInitialize();
  Future<void> senderLoop();
  void updateAutoLight(); 
}

// --- 3. MOULD KING MODERN (BLE) ---
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

  String _pctToHex(double pct) {
    if (pct == 0) return "0000";
    int val = (pct.abs() / 100.0 * 32767).toInt();
    if (pct < 0) val += 0x8000;
    return val.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  @override
  Future<void> senderLoop() async {
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
      String hexB = lightB > 0 ? (config.autoLight ? (lastDirForward ? "7FFF" : "81FF") : _pctToHex(lightB.toDouble())) : "0000";
      String hexC = _pctToHex(lightC.toDouble());
      
      String cmdStr = "T1440${hexA}${hexB}${hexC}000${hexD}W";
      
      try {
        await writeCharacteristic!.write([0x01], withoutResponse: true);
        await writeCharacteristic!.write(utf8.encode(cmdStr), withoutResponse: true);
      } catch (e) { break; }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void setLight(String port, bool isOn) {
    int val = isOn ? 100 : 0;
    if (port.toUpperCase() == 'B') lightB = val;
    if (port.toUpperCase() == 'C') lightC = val;
    onStatusChanged?.call();
  }

  @override
  void updateAutoLight() {}  
}

// --- 4. CIRCUIT CUBE (BLE) ---
class CircuitCubeController extends TrainController {
  final Map<String, bool> _activeLights = {'a': false, 'b': false, 'c': false};

  CircuitCubeController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    device = BluetoothDevice.fromId(config.mac);

    device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && isRunning) {
        isRunning = false;
        onStatusChanged?.call();
      }
    });

    await device!.connect(timeout: const Duration(seconds: 10));
    List<BluetoothService> services = await device!.discoverServices();
    for (var s in services) {
      if (s.uuid.toString().toLowerCase() == "6e400001-b5a3-f393-e0a9-e50e24dcca9e") {
        for (var c in s.characteristics) {
          if (c.uuid.toString().toLowerCase() == "6e400002-b5a3-f393-e0a9-e50e24dcca9e") {
            writeCharacteristic = c;
          }
        }
      }
    }

    if (writeCharacteristic != null) {
      isRunning = true;
      onStatusChanged?.call();
      senderLoop();
    }
  }

  void _sendCommand(String channel, int speed) {
    if (writeCharacteristic == null || !isRunning) return;
    String dir = speed >= 0 ? "+" : "-";
    int cubeSpeed = ((speed.abs() / 100.0) * 255).round().clamp(0, 255);
    String command = "$dir${cubeSpeed.toString().padLeft(3, '0')}${channel.toLowerCase()}";
    writeCharacteristic!.write(command.codeUnits, withoutResponse: true);
  }

  @override
  Future<void> senderLoop() async {
    while (isRunning) {
      if (currentSpeed != targetSpeed) {
        if (currentSpeed < targetSpeed) {
          currentSpeed += config.rampStep;
          if (currentSpeed > targetSpeed) currentSpeed = targetSpeed;
        } else if (currentSpeed > targetSpeed) {
          currentSpeed -= config.rampStep;
          if (currentSpeed < targetSpeed) currentSpeed = targetSpeed;
        }
        
        config.portSettings.forEach((port, role) {
          if (role.toLowerCase() == 'motor') _sendCommand(port, currentSpeed.toInt());
        });
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  void setLight(String port, bool isOn) {
    String p = port.toLowerCase();
    _activeLights[p] = isOn;
    int val = isOn ? 100 : 0;
    if (p == 'b') lightB = val;
    if (p == 'c') lightC = val;

    if (!isOn) {
      _sendCommand(p, 0);
    } else {
      _sendCommand(p, config.autoLight ? (lastDirForward ? 100 : -100) : 100);
    }
    onStatusChanged?.call();
  }

  @override
  void updateAutoLight() {}

  @override
  void emergencyStop() {
    super.emergencyStop();
    config.portSettings.forEach((port, role) {
      if (role.toLowerCase() == 'motor') _sendCommand(port, 0);
    });
  }
}

// --- 5. LEGO POWERED UP ---
class LegoHubController extends TrainController {
  final String serviceUuid = "00001623-1212-efde-1623-785feabcd123";
  final String charUuid = "00001624-1212-efde-1623-785feabcd123";

  LegoHubController(super.config);

  @override
Future<void> connectAndInitialize() async {
  device = BluetoothDevice.fromId(config.mac);

  // Status-Überwachung (wie gehabt)
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
    // Wir setzen subscribeToServicesChanged auf FALSE
    List<BluetoothService> services = await device!.discoverServices(
      subscribeToServicesChanged: false 
    );
    
    for (var service in services) {
      // Wir suchen NUR nach der LEGO-Service UUID
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
      senderLoop();
    } else {
      // Falls wir nichts finden, trennen wir sauber, um keinen Zombie-GATT zu haben
      await device!.disconnect();
    }
  } catch (e) {
    debugPrint("LEGO Hub Verbindungsfehler: $e");
    isRunning = false;
    onStatusChanged?.call();
  }
}

  void _sendPortSpeed(int portIndex, int speed, bool invert) {
    if (writeCharacteristic == null) return;
    int finalSpeed = invert ? -speed : speed;
    finalSpeed = finalSpeed.clamp(-100, 100);

    List<int> cmd = [
      0x08, 0x00, 0x81, portIndex, 0x11, 0x51, 0x00, finalSpeed.toUnsigned(8)
    ];
    writeCharacteristic!.write(cmd, withoutResponse: true);
  }

  @override
  void setLight(String portName, bool on) {
    if (writeCharacteristic == null) return;
    if (config.portSettings[portName] == 'light') {
      int portIndex = (portName == 'A') ? 0 : 1;
      int brightness = on ? 100 : 0;
      if (portName == 'A') lightA = brightness;
      if (portName == 'B') lightB = brightness;
      _sendPortSpeed(portIndex, brightness, false);
      onStatusChanged?.call();
    }
  }

  @override
  Future<void> senderLoop() async {
    int lastSentSpeedInt = -999;
    while (isRunning && writeCharacteristic != null) {
      if (currentSpeed < targetSpeed) {
        currentSpeed += config.rampStep;
        if (currentSpeed > targetSpeed) currentSpeed = targetSpeed;
      } else if (currentSpeed > targetSpeed) {
        currentSpeed -= config.rampStep;
        if (currentSpeed < targetSpeed) currentSpeed = targetSpeed;
      }

      int speedInt = currentSpeed.round();
      if (speedInt != lastSentSpeedInt) {
        for (var port in ['A', 'B']) {
          String setting = config.portSettings[port] ?? 'none';
          if (setting.contains('motor')) {
            if (port == 'B' && config.autoLight && config.portSettings['B'] == 'light') continue;
            _sendPortSpeed(port == 'A' ? 0 : 1, speedInt, setting == 'motor_inv');
          }
        }
        lastSentSpeedInt = speedInt;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  void updateAutoLight() {
    if (writeCharacteristic == null || !config.autoLight) return;
    config.portSettings.forEach((port, setting) {
      if (setting == 'light') {
        _sendPortSpeed(port == 'A' ? 0 : 1, lastDirForward ? 100 : 0, false);
      }
    });
  }
}