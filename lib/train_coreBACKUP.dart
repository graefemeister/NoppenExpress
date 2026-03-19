import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;

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
  int lightB = 0; 
  int lightC = 0;

  BluetoothDevice? device;
  BluetoothCharacteristic? writeCharacteristic;

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
  
  void setLight(String port, bool isOn) {
    int val = isOn ? 100 : 0;
    if (port.toUpperCase() == 'B') lightB = val;
    if (port.toUpperCase() == 'C') lightC = val;
  }

  void applyRamping() {
    double step = (targetSpeed.abs() > currentSpeed.abs()) ? config.rampStep : 3.0; 
    if (currentSpeed < targetSpeed) {
      currentSpeed = (currentSpeed + step > targetSpeed) ? targetSpeed : currentSpeed + step;
    } else if (currentSpeed > targetSpeed) {
      currentSpeed = (currentSpeed - step < targetSpeed) ? targetSpeed : currentSpeed - step;
    }
  }

  Future<void> disconnect() async {
    isRunning = false;
    if (device != null) await device!.disconnect();
  }

  Future<void> connectAndInitialize();
  Future<void> senderLoop();
  void updateAutoLight(); 
}

// --- 3. MOULD KING MODERN (BLE) ---
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
      String hexB;
            if (lightB > 0) {
        if (config.autoLight) {
          hexB = lastDirForward ? "7FFF" : "81FF";
        } else {
          // Wenn Automatik aus ist: Ganz normal an (manuell)
          hexB = _pctToHex(lightB.toDouble()); 
        }
      } else {
        // Licht-Button auf dem Display ist aus
        hexB = "0000";
      }
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
  void updateAutoLight() {
    // Bleibt leer, da die Lichtsteuerung 
    // bereits automatisch im senderLoop passiert!
  }  
}

// --- 4. CIRCUIT CUBE (BLE) ---
class CircuitCubeController extends TrainController {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar;

  // Wir merken uns, welche Lichter manuell eingeschaltet wurden
  final Map<String, bool> _activeLights = {'a': false, 'b': false, 'c': false};

  CircuitCubeController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    try {
      print("Circuit Cube: Verbinde mit ${config.mac}...");
      
      _device = BluetoothDevice.fromId(config.mac);
      await _device!.connect(timeout: const Duration(seconds: 10));
      
      List<BluetoothService> services = await _device!.discoverServices();
      for (var s in services) {
        if (s.uuid.toString().toLowerCase() == "6e400001-b5a3-f393-e0a9-e50e24dcca9e") {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() == "6e400002-b5a3-f393-e0a9-e50e24dcca9e") {
              _txChar = c;
            }
          }
        }
      }

      if (_txChar == null) {
        throw Exception("Nordic UART Service auf dem Cube nicht gefunden!");
      }

      isRunning = true;
      print("!!! CIRCUIT CUBE VERBUNDEN !!!");
      stop(); 
      
      // Den Ramping-Loop starten
      senderLoop();
      
    } catch (e) {
      isRunning = false;
      _device = null;
      print("Circuit Cube Fehler: $e");
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    stop();
    await Future.delayed(const Duration(milliseconds: 100));
    await _device?.disconnect();
    isRunning = false;
    _txChar = null;
  }

  // --- DIE KERN-FUNKTION FÜR DEN CUBE ---
  void _sendCommand(String channel, int speed) {
    if (_txChar == null || !isRunning) return;

    String dir = speed >= 0 ? "+" : "-";
    int cubeSpeed = ((speed.abs() / 100.0) * 255).round().clamp(0, 255);
    String speedStr = cubeSpeed.toString().padLeft(3, '0');
    
    // Ohne \n für maximale Kompatibilität!
    String command = "$dir$speedStr${channel.toLowerCase()}";
    
    _txChar!.write(command.codeUnits, withoutResponse: true);
  }

  // --- FAHRSTUFEN & RAMPING ---
  
  @override
  void setGear(int gear, {bool forward = true}) {
    // 1. Alten Richtungsstand merken
    bool oldDir = lastDirForward;
    
    // 2. Basisklasse updaten (setzt targetSpeed und lastDirForward)
    super.setGear(gear, forward: forward);

    // 3. Richtungswechsel: Polen wir das Licht um?
    // JA, aber NUR wenn AutoLight (Umpolen) aktiv ist UND das Licht gerade AN ist!
    if (oldDir != lastDirForward && config.autoLight) {
      config.portSettings.forEach((port, role) {
        String p = port.toLowerCase();
        if (role.toLowerCase() == 'light' && _activeLights[p] == true) {
          _sendCommand(p, lastDirForward ? 100 : -100);
        }
      });
    }
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
        
        int speedInt = currentSpeed.toInt();
        bool motorFound = false;

        // An alle Motoren senden
        config.portSettings.forEach((port, role) {
          String p = port.toLowerCase();
          if (role.toLowerCase() == 'motor') {
            motorFound = true;
            _sendCommand(p, speedInt);
          }
        });

        // Fallback: Wenn kein Motor konfiguriert ist, feuere auf A
        if (!motorFound) {
          _sendCommand('a', speedInt);
        }
      }
      
      // 100 Millisekunden Pause = 10 sanfte Anpassungen pro Sekunde
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // --- LICHT-LOGIK ---

  @override
  void setLight(String port, bool isOn) {
    super.setLight(port, isOn); // Basisklasse informieren
    String p = port.toLowerCase();
    
    _activeLights[p] = isOn; // Der Master-Status: Was der User sagt, gilt!
    
    if (!isOn) {
      // User sagt AUS, also ist es strikt AUS. Keine Diskussion.
      _sendCommand(p, 0); 
    } else {
      // User sagt AN. Prüfen wir, ob wir das automatische Umpolen nutzen sollen:
      if (config.autoLight) {
        _sendCommand(p, lastDirForward ? 100 : -100);
      } else {
        // Umpolen deaktiviert -> Licht brennt immer "normal" (vorwärts)
        _sendCommand(p, 100);
      }
    }
  }

  @override
  void updateAutoLight() {
    // Diese Funktion lassen wir absichtlich leer!
    // Das Licht soll sich NICHT mehr selbstständig ein- oder ausschalten, 
    // wenn die Lok anfährt oder bremst. Der Button im UI hat die alleinige Macht.
  }

  @override
  void emergencyStop() {
    super.emergencyStop();
    stop();
  }

  @override
  void stop() {
    targetSpeed = 0.0;
    currentSpeed = 0.0;
    
    bool motorFound = false;

    // Wir greifen beim Stop NUR die Motoren an. Das Licht bleibt exakt so, 
    // wie der User es am Dashboard eingestellt hat (an bleibt an, aus bleibt aus).
    config.portSettings.forEach((port, role) {
      String p = port.toLowerCase();
      if (role.toLowerCase() == 'motor') {
        motorFound = true;
        _sendCommand(p, 0);
      }
    });

    // Sicherheitsnetz für alte Loks ohne Port-Konfiguration
    if (!motorFound) _sendCommand('a', 0);
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
    
    // Alte Verbindungen sicher killen
    try { await device!.disconnect(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await device!.connect(timeout: const Duration(seconds: 5));
      
      List<BluetoothService> services = [];
      try {
        services = await device!.discoverServices(subscribeToServicesChanged: false);
      } catch (_) {
        // Fängt den bekannten 2a05-Fehler bei Lego Hubs leise ab
        services = device!.servicesList; 
      }
      
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
        senderLoop();
      }
    } catch (e) {
      throw Exception("LEGO Verbindung fehlgeschlagen: $e"); 
    }
  }

  void _sendPortSpeed(int portIndex, int speed, bool invert) {
    if (writeCharacteristic == null) return;
    int finalSpeed = invert ? -speed : speed;
    
    List<int> cmd = [
      0x08, 0x00, 0x81, portIndex, 0x11, 0x51, 0x00, finalSpeed.toUnsigned(8)
    ];
    writeCharacteristic!.write(cmd, withoutResponse: true);
  }

  @override
  Future<void> senderLoop() async {
    isRunning = true;
    int lastSentSpeedInt = -999;

    while (isRunning && writeCharacteristic != null) {
      // 1. Ramping berechnen (sanftes Anfahren und Bremsen)
      if (currentSpeed < targetSpeed) {
        currentSpeed += config.rampStep;
        if (currentSpeed > targetSpeed) currentSpeed = targetSpeed;
      } else if (currentSpeed > targetSpeed) {
        currentSpeed -= config.rampStep;
        if (currentSpeed < targetSpeed) currentSpeed = targetSpeed;
      }

      // 2. Geschwindigkeit runden für saubere Bluetooth-Übertragung
      int speedInt = currentSpeed.round();

      // 3. Nur senden, wenn sich der ganzzahlige Wert wirklich geändert hat
      if (speedInt != lastSentSpeedInt) {
        String configA = config.portSettings['A'] ?? 'motor';
        if (configA.contains('motor')) {
          _sendPortSpeed(0, speedInt, configA == 'motor_inv');
        }

        String configB = config.portSettings['B'] ?? 'motor';
        if (configB.contains('motor') && !config.autoLight) {
          _sendPortSpeed(1, speedInt, configB == 'motor_inv');
        }
        
        lastSentSpeedInt = speedInt;
      }
      
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  void updateAutoLight() {
    if (writeCharacteristic == null || !config.autoLight) return;
    
    int lightPower = lastDirForward ? 100 : -100;
    if (lightB == 0) lightPower = 0;

    _sendPortSpeed(1, lightPower, false);
  }
}

// --- 6. MOULD KING CLASSIC (SPP) ---
class MouldKingClassicController extends TrainController {
  classic.BluetoothConnection? _conn;
  MouldKingClassicController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    _conn = await classic.BluetoothConnection.toAddress(config.mac);
    isRunning = true;
    senderLoop();
  }

  @override void updateAutoLight() {}

  @override
  Future<void> senderLoop() async {
    while (isRunning && _conn != null && _conn!.isConnected) {
      applyRamping();
      int dir = currentSpeed > 0 ? 1 : (currentSpeed < 0 ? 2 : 0);
      _conn!.output.add(Uint8List.fromList([0x64, 0x00, 0x4d, 0x73, 1, dir, currentSpeed.abs().round()]));
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  Future<void> disconnect() async { isRunning = false; await _conn?.close(); }
}