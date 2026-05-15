import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import '../mould_king_40_protocol.dart'; 
import '../train_manager.dart';
import '../models/pfx_action.dart';

// --- 1. DIE DATENSTRUKTUR ---
class TrainConfig {
  final String id;
  String mac;
  String protocol;
  int? channel;
  String name;
  String notes;
  Map<int, double> gears;
  int rampStep;
  int rampStep2;
  int brakeStep;
  int brakeStep2;
  int vMin;
  int vMax;
  Map<String, String> portSettings;
  int deltaStep; 
  int rampDelay;
  int rampDelay2;
  bool isManualMode;
  bool useRampingProfile2;
  String imagePath;
  int buWizzPowerMode;
  List<PFxAction> pfxActions = [];

  TrainConfig({
    required this.id,
    required this.name,
    required this.mac,
    required this.protocol,
    this.channel = 1,
    this.imagePath = "",
    this.notes = "",
    this.gears = const {0: 0, 1: 25, 2: 50, 3: 75, 4: 100},
    this.rampStep = 2,
    this.rampStep2 = 1,
    this.brakeStep = 3,
    this.brakeStep2 = 1,
    this.vMin = 25,
    this.vMax = 100,
    this.portSettings = const {'A': 'motor', 'B': 'light_dir'}, 
    this.deltaStep = 10, 
    this.rampDelay = 100,
    this.rampDelay2 = 250,
    this.isManualMode = false,
    this.useRampingProfile2 = false,
    this.buWizzPowerMode = 2, // Standard-Fallback ist immer Normal (2)
    List<PFxAction>? pfxActions, // Optional im Konstruktor
  }) : pfxActions = pfxActions ?? []; // Wenn nichts übergeben wird, ist sie leer

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'name': name, 'mac': mac, 'protocol': protocol,
      'channel': channel, 
      'imagePath': imagePath, 'notes': notes,
      'gears': gears.map((k, v) => MapEntry(k.toString(), v)),
      'rampStep': rampStep, 'rampStep2': rampStep2, 
      'brakeStep': brakeStep, 'brakeStep2': brakeStep2,
      'vMin': vMin, 'vMax': vMax,
      'portSettings': portSettings,
      'deltaStep': deltaStep, 
      'rampDelay': rampDelay, 'rampDelay2': rampDelay2,
      'useRampingProfile2': useRampingProfile2,
      'isManualMode': isManualMode, 
      'buWizzPowerMode': buWizzPowerMode,
      'pfxActions': pfxActions.map((action) => action.toJson()).toList(),
    };
  }

  factory TrainConfig.fromMap(Map<String, dynamic> map) {
    // Lade alte Port-Settings oder setze Standard
    Map<String, String> loadedPorts = Map<String, String>.from(
        map['portSettings'] ?? {'A': 'motor', 'B': 'light_dir'});

    // MIGRATION: Falls die alte Config "inverted: true" hatte
    bool oldInverted = map['inverted'] ?? false;
    if (oldInverted) {
      loadedPorts.forEach((key, value) {
        if (value == 'motor') loadedPorts[key] = 'motor_inv';
      });
    }

    // PFx Aktionen aus der Map wiederherstellen
    List<PFxAction> loadedActions = [];
    if (map['pfxActions'] != null) {
      loadedActions = (map['pfxActions'] as List)
          .map((item) => PFxAction.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return TrainConfig(
      id: map['id'], name: map['name'], mac: map['mac'], protocol: map['protocol'],
      channel: map['channel'],
      imagePath: map['imagePath'] ?? "", notes: map['notes'] ?? "",
      gears: (map['gears'] as Map).map((k, v) => MapEntry(int.parse(k), v.toDouble())),
      rampStep: ((map['rampStep'] as num?)?.toInt() ?? 1).clamp(1, 25),
      rampStep2: ((map['rampStep2'] as num?)?.toInt() ?? 1).clamp(1, 25),
      brakeStep: ((map['brakeStep'] as num?)?.toInt() ?? 3).clamp(1, 25),
      brakeStep2: ((map['brakeStep2'] as num?)?.toInt() ?? 1).clamp(1, 25),
      vMin: map['vMin'] ?? 25,
      vMax: map['vMax'] ?? 100,
      portSettings: loadedPorts, // Migrierte Ports übergeben
      deltaStep: map['deltaStep'] ?? 10, 
      rampDelay: map['rampDelay'] ?? 100,
      rampDelay2: map['rampDelay2'] ?? 250,
      useRampingProfile2: map['useRampingProfile2'] ?? false,
      isManualMode: map['isManualMode'] ?? false,
      buWizzPowerMode: map['buWizzPowerMode'] ?? 2, // NEW: Retrieve from map
      pfxActions: loadedActions, // Hier geben wir die geladenen Buttons an den Konstruktor
    );
  }
}

// --- 2. DIE ZENTRALE BASISKLASSE ---
abstract class TrainController {
  TrainConfig config;
  bool isRunning = false;
  
  bool get useRampingProfile2 => config.useRampingProfile2; 
  String get name => config.name;
  String get mac => config.mac;
  int get channel => config.channel ?? 1;
  String get imagePath => config.imagePath;

  double currentSpeed = 0.0; 
  double targetSpeed = 0.0;  
  Timer? _centralRampingTimer;

  bool lastDirForward = true;

  // NEUE STATE VARIABLEN FÜR FREIE PORTS
  bool isLightOn = false;
  bool isDoorActive = false;
  bool nextDoorDirectionForward = true;

  BluetoothDevice? device;
  BluetoothCharacteristic? writeCharacteristic;
  VoidCallback? onStatusChanged;

  TrainController(this.config);

  void updateConfig(TrainConfig newConfig) {
    if (config.id != newConfig.id) {
      print("Warnung: Config-Update für eine andere Lok-ID!");
    }
    config = newConfig;
    if (onStatusChanged != null) onStatusChanged!();
  }

  // HILFSFUNKTION FÜR HARDWARE-CONTROLLER
  int getPowerForRole(String role) {
    switch (role) {
      case 'motor': 
        return currentSpeed.round();
      case 'motor_inv': 
        return -currentSpeed.round();
      case 'light_static': 
        return isLightOn ? 100 : 0;
      case 'light_dir': 
        return isLightOn ? (lastDirForward ? 100 : -100) : 0;
      case 'door': 
        return isDoorActive ? (nextDoorDirectionForward ? 100 : -100) : 0;
      case 'none':
      default: 
        return 0;
    }
  }

  void toggleLight() {
    isLightOn = !isLightOn;
    sendHardwareCommand();
    if (onStatusChanged != null) onStatusChanged!();
  }

  void toggleDoor() {
    isDoorActive = !isDoorActive;
    if (!isDoorActive) {
      nextDoorDirectionForward = !nextDoorDirectionForward;
    }
    sendHardwareCommand();
    if (onStatusChanged != null) onStatusChanged!();
  }

  void setGear(int gear, {bool forward = true}) {
    if (config.gears.containsKey(gear)) {
      double speed = config.gears[gear]!;
      _setTargetAndRamp(speed, forward: forward, isManual: false);
    }
  }

  void setTargetSpeed(int targetPercent, {bool forward = true}) {
    _setTargetAndRamp(targetPercent.toDouble(), forward: forward, isManual: true);
  }

  // DAS ZENTRALE GEHIRN (RAMPING)
  void _setTargetAndRamp(double speedInput, {required bool forward, required bool isManual}) {
    if (!isRunning) return;

    if (speedInput > 0) lastDirForward = forward;
    
    double absTarget = speedInput.abs(); 
    targetSpeed = forward ? absTarget : -absTarget;

    double activeRampStep = (useRampingProfile2 ? config.rampStep2 : config.rampStep).toDouble();
    double activeBrakeStep = (useRampingProfile2 ? config.brakeStep2 : config.brakeStep).toDouble();
    int activeRampDelay = useRampingProfile2 ? config.rampDelay2 : config.rampDelay;
    
    double minSpeed = config.vMin.toDouble();

    if (absTarget > config.vMax) {
      absTarget = config.vMax.toDouble();
    }

    _centralRampingTimer?.cancel();
    
    _centralRampingTimer = Timer.periodic(Duration(milliseconds: activeRampDelay), (timer) {
      if (currentSpeed == targetSpeed) {
        timer.cancel();
        return;
      }

      bool isAccelerating = targetSpeed.abs() > currentSpeed.abs();
      double step = isAccelerating ? activeRampStep : activeBrakeStep;

      double effectiveTarget = targetSpeed;
      if (targetSpeed.abs() > 0 && targetSpeed.abs() < minSpeed) {
        effectiveTarget = (targetSpeed > 0) ? minSpeed : -minSpeed;
      }

      if (currentSpeed < effectiveTarget) {
        if (currentSpeed == 0 && effectiveTarget > 0) {
          // Falls vMin (minSpeed) 0 ist, nehmen wir direkt den ersten 'step'
          currentSpeed = (minSpeed > 0) ? minSpeed : step; 
        } else {
          currentSpeed = (currentSpeed + step > effectiveTarget) ? effectiveTarget : currentSpeed + step;
        }
      } else if (currentSpeed > effectiveTarget) {
        if (currentSpeed == 0 && effectiveTarget < 0) {
          // Gleiches gilt für Rückwärtsfahrt
          currentSpeed = (minSpeed > 0) ? -minSpeed : -step; 
        } else {
          currentSpeed = (currentSpeed - step < effectiveTarget) ? effectiveTarget : currentSpeed - step;
        }
      }

      if (effectiveTarget == 0 && currentSpeed.abs() < step) {
        currentSpeed = 0;
      }

      sendHardwareCommand();
      if (onStatusChanged != null) onStatusChanged!();
    });
  }

  void sendHardwareCommand();

  void emergencyStop() { 
    targetSpeed = 0.0; 
    currentSpeed = 0.0; 
    _centralRampingTimer?.cancel();
    sendHardwareCommand(); 
    if (onStatusChanged != null) onStatusChanged!();
  }

  void setLight(String port, bool isOn) {
    isLightOn = isOn;
    sendHardwareCommand();
    if (onStatusChanged != null) onStatusChanged!();
  }

  Future<void> disconnect() async {
    isRunning = false;
    _centralRampingTimer?.cancel();
    currentSpeed = 0.0;
    targetSpeed = 0.0;
    
    await device?.disconnect();
    onStatusChanged?.call();
  }

  Future<void> connectAndInitialize();
  Future<void> senderLoop();
}