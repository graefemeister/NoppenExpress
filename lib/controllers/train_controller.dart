import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pfx_action.dart';

// --- 0. GEKOPPELTE EINHEIT (DOPPELTRAKTION) ---
class CoupledUnit {
  final String locoId;
  final bool isReversed; // true = Rücken an Rücken (Fahrtrichtung umkehren)
  int trim; // Trimmung in Prozent (-50 bis +50, Standard 0)

  CoupledUnit({
    required this.locoId,
    this.isReversed = false,
    this.trim = 0,
  });

  Map<String, dynamic> toMap() => {
    'locoId': locoId,
    'isReversed': isReversed,
    'trim': trim,
  };

  factory CoupledUnit.fromMap(Map<String, dynamic> map) => CoupledUnit(
    locoId: map['locoId'] as String,
    isReversed: map['isReversed'] as bool? ?? false,
    trim: (map['trim'] as num?)?.toInt() ?? 0,
  );
}

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
  Map<String, int> portMaxPower;
  int lightFadeMs;
  int deltaStep;
  int rampDelay;
  int rampDelay2;
  bool isManualMode;
  bool useRampingProfile2;
  String imagePath;
  int buWizzPowerMode;
  int lowBatteryCutoff;
  List<PFxAction> pfxActions = [];
  List<CoupledUnit> coupledUnits = [];

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
    Map<String, int>? portMaxPower,
    this.lightFadeMs = 300,
    this.deltaStep = 10,
    this.rampDelay = 100,
    this.rampDelay2 = 250,
    this.isManualMode = false,
    this.useRampingProfile2 = false,
    this.buWizzPowerMode = 2, // Standard-Fallback ist immer Normal (2)
    this.lowBatteryCutoff = 10, // 0 = Aus, Standard 10%
    List<PFxAction>? pfxActions, // Optional im Konstruktor
    List<CoupledUnit>? coupledUnits,
  }) : pfxActions = pfxActions ?? [],
       coupledUnits = coupledUnits ?? [],
       portMaxPower = portMaxPower != null ? Map<String, int>.from(portMaxPower) : {};

  bool get supportsBatteryTelemetry {
    final p = protocol.toLowerCase();
    return p == 'lego_hub' ||
        p.contains('buwizz') ||
        p == 'circuit_cube' ||
        p == 'sbrick';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mac': mac,
      'protocol': protocol,
      'channel': channel,
      'imagePath': imagePath,
      'notes': notes,
      'gears': gears.map((k, v) => MapEntry(k.toString(), v)),
      'rampStep': rampStep,
      'rampStep2': rampStep2,
      'brakeStep': brakeStep,
      'brakeStep2': brakeStep2,
      'vMin': vMin,
      'vMax': vMax,
      'portSettings': portSettings,
      'portMaxPower': portMaxPower,
      'lightFadeMs': lightFadeMs,
      'deltaStep': deltaStep,
      'rampDelay': rampDelay,
      'rampDelay2': rampDelay2,
      'useRampingProfile2': useRampingProfile2,
      'isManualMode': isManualMode,
      'buWizzPowerMode': buWizzPowerMode,
      'lowBatteryCutoff': lowBatteryCutoff,
      'pfxActions': pfxActions.map((action) => action.toJson()).toList(),
      'coupledUnits': coupledUnits.map((unit) => unit.toMap()).toList(),
    };
  }

  factory TrainConfig.fromMap(Map<String, dynamic> map) {
    // Lade alte Port-Settings oder setze Standard
    Map<String, String> loadedPorts = Map<String, String>.from(
      map['portSettings'] ?? {'A': 'motor', 'B': 'light_dir'},
    );

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

    // Gekoppelte Einheiten (Doppeltraktion) wiederherstellen
    List<CoupledUnit> loadedCoupledUnits = [];
    if (map['coupledUnits'] != null) {
      loadedCoupledUnits = (map['coupledUnits'] as List)
          .map((item) => CoupledUnit.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    // Port-Max-Power (Helligkeitsbegrenzung pro Port) wiederherstellen
    Map<String, int> loadedMaxPower = {};
    if (map['portMaxPower'] != null) {
      loadedMaxPower = Map<String, int>.from(
        (map['portMaxPower'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt().clamp(1, 100)),
        ),
      );
    }

    return TrainConfig(
      id: map['id'],
      name: map['name'],
      mac: map['mac'],
      protocol: map['protocol'],
      channel: map['channel'],
      imagePath: map['imagePath'] ?? "",
      notes: map['notes'] ?? "",
      gears: (map['gears'] as Map).map(
        (k, v) => MapEntry(int.parse(k), v.toDouble()),
      ),
      rampStep: ((map['rampStep'] as num?)?.toInt() ?? 1).clamp(1, 25),
      rampStep2: ((map['rampStep2'] as num?)?.toInt() ?? 1).clamp(1, 25),
      brakeStep: ((map['brakeStep'] as num?)?.toInt() ?? 3).clamp(1, 25),
      brakeStep2: ((map['brakeStep2'] as num?)?.toInt() ?? 1).clamp(1, 25),
      vMin: map['vMin'] ?? 25,
      vMax: map['vMax'] ?? 100,
      portSettings: loadedPorts, // Migrierte Ports übergeben
      portMaxPower: loadedMaxPower,
      lightFadeMs: ((map['lightFadeMs'] as num?)?.toInt() ?? 300).clamp(0, 2000),
      deltaStep: map['deltaStep'] ?? 10,
      rampDelay: map['rampDelay'] ?? 100,
      rampDelay2: map['rampDelay2'] ?? 250,
      useRampingProfile2: map['useRampingProfile2'] ?? false,
      isManualMode: map['isManualMode'] ?? false,
      buWizzPowerMode: map['buWizzPowerMode'] ?? 2, // NEW: Retrieve from map
      lowBatteryCutoff: ((map['lowBatteryCutoff'] as num?)?.toInt() ?? 10).clamp(0, 50),
      pfxActions: loadedActions,
      coupledUnits: loadedCoupledUnits,
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
  final Map<String, bool> _portLightState = {};
  final Map<String, double> _portLightBrightness = {};
  Timer? _lightFadeTimer;
  bool isDoorActive = false;
  bool isSmokeOn = false;
  bool nextDoorDirectionForward = true;

  // TELEMETRIE: AKKUSTAND (0-100%, null wenn nicht unterstützt)
  int? _batteryLevel;
  int? get batteryLevel => _batteryLevel;
  set batteryLevel(int? value) {
    if (_batteryLevel != value) {
      _batteryLevel = value;
      checkBatteryCutoff();
      consistMaster?.checkBatteryCutoff();
    }
  }

  bool _hasTriggeredLowBatteryCutoff = false;
  void Function(String locoName, int batteryLevel)? onLowBatteryWarning;
  TrainController? consistMaster;

  void checkBatteryCutoff() {
    final level = effectiveBatteryLevel;
    if (level == null || config.lowBatteryCutoff <= 0) return;

    if (level <= config.lowBatteryCutoff) {
      if (!_hasTriggeredLowBatteryCutoff) {
        if (currentSpeed != 0 || targetSpeed != 0) {
          _hasTriggeredLowBatteryCutoff = true;
          debugPrint("[Akkuschutz] Schwellwert (${config.lowBatteryCutoff}%) erreicht für ${config.name} (Ist: $level%). Ramping auf 0!");
          setTargetSpeed(0);
          onLowBatteryWarning?.call(name, level);
        }
      }
    } else {
      _hasTriggeredLowBatteryCutoff = false;
    }
  }

  int? get effectiveBatteryLevel {
    if (!isRunning) return null;
    int? minBattery = batteryLevel;
    if (isConsistMaster) {
      for (final slave in coupledControllers) {
        if (slave.isRunning && slave.batteryLevel != null) {
          if (minBattery == null || slave.batteryLevel! < minBattery) {
            minBattery = slave.batteryLevel;
          }
        }
      }
    }
    return minBattery;
  }

  // --- GEKOPPELTE EINHEITEN (DOPPELTRAKTION) ---
  List<TrainController> _coupledControllers = [];
  List<TrainController> get coupledControllers => _coupledControllers;
  set coupledControllers(List<TrainController> list) {
    _coupledControllers = list;
    for (final s in list) {
      s.consistMaster = this;
    }
  }
  bool get isConsistMaster => config.coupledUnits.isNotEmpty;

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

  bool isPortLightOn(String port) {
    return _portLightState[port] ?? isLightOn;
  }

  void _startLightFading() {
    if (config.lightFadeMs <= 0) {
      _lightFadeTimer?.cancel();
      _lightFadeTimer = null;
      config.portSettings.forEach((port, role) {
        if (role.contains('light')) {
          _portLightBrightness[port] = isPortLightOn(port) ? 1.0 : 0.0;
        }
      });
      sendHardwareCommand();
      if (onStatusChanged != null) onStatusChanged!();
      return;
    }

    _lightFadeTimer?.cancel();
    const int tickMs = 30;
    final double step = tickMs / config.lightFadeMs;

    _lightFadeTimer = Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
      bool allReached = true;
      for (final entry in config.portSettings.entries) {
        if (!entry.value.contains('light')) continue;
        final port = entry.key;
        final double target = isPortLightOn(port) ? 1.0 : 0.0;
        double current = _portLightBrightness[port] ?? (target == 1.0 ? 0.0 : 1.0);

        if ((current - target).abs() <= step) {
          current = target;
        } else if (current < target) {
          current = (current + step).clamp(0.0, 1.0);
          allReached = false;
        } else {
          current = (current - step).clamp(0.0, 1.0);
          allReached = false;
        }
        _portLightBrightness[port] = current;
      }

      sendHardwareCommand();
      if (onStatusChanged != null) onStatusChanged!();

      if (allReached) {
        timer.cancel();
        _lightFadeTimer = null;
      }
    });
  }

  // HILFSFUNKTION FÜR HARDWARE-CONTROLLER
  int getPowerForRole(String role, [String? port]) {
    final bool activeLight = port != null ? isPortLightOn(port) : isLightOn;
    final int configuredMax = (port != null ? config.portMaxPower[port] : null) ?? 100;
    final double fadeFactor = port != null
        ? (_portLightBrightness[port] ?? (activeLight ? 1.0 : 0.0))
        : (activeLight ? 1.0 : 0.0);
    final int effectivePower = (configuredMax * fadeFactor).round();

    switch (role) {
      case 'motor':
        return currentSpeed.round();
      case 'motor_inv':
        return -currentSpeed.round();
      case 'light_static':
        return effectivePower;
      case 'light_static_inv':
        return -effectivePower;
      case 'light_dir':
        return lastDirForward ? effectivePower : -effectivePower;
      case 'light_dir_inv':
        return lastDirForward ? -effectivePower : effectivePower;
      case 'door':
        return isDoorActive ? (nextDoorDirectionForward ? 100 : -100) : 0;
      case 'smoke':
        return isSmokeOn ? 100 : 0;
      case 'none':
      default:
        return 0;
    }
  }

  void togglePortLight(String port, [bool? explicitState]) {
    final bool current = isPortLightOn(port);
    final bool next = explicitState ?? !current;
    _portLightState[port] = next;
    isLightOn = _portLightState.values.any((on) => on);
    _startLightFading();
    for (var slave in coupledControllers) {
      if (slave.config.portSettings.containsKey(port)) {
        slave.togglePortLight(port, next);
      } else {
        final slaveLightPorts = slave.config.portSettings.entries
            .where((e) => e.value.contains('light'))
            .toList();
        if (slaveLightPorts.length == 1) {
          slave.togglePortLight(slaveLightPorts.first.key, next);
        }
      }
    }
    if (onStatusChanged != null) onStatusChanged!();
  }

  void toggleLight([bool? explicitState]) {
    isLightOn = explicitState ?? !isLightOn;
    config.portSettings.forEach((port, role) {
      if (role.contains('light')) {
        _portLightState[port] = isLightOn;
      }
    });
    _startLightFading();
    for (var slave in coupledControllers) {
      slave.toggleLight(isLightOn);
    }
    if (onStatusChanged != null) onStatusChanged!();
  }

  void toggleDoor() {
    isDoorActive = !isDoorActive;
    if (!isDoorActive) {
      nextDoorDirectionForward = !nextDoorDirectionForward;
    }
    sendHardwareCommand();
    for (var slave in coupledControllers) {
      slave.isDoorActive = isDoorActive;
      slave.sendHardwareCommand();
    }
    if (onStatusChanged != null) onStatusChanged!();
  }

  void toggleSmoke() {
    isSmokeOn = !isSmokeOn;
    sendHardwareCommand();
    for (var slave in coupledControllers) {
      slave.isSmokeOn = isSmokeOn;
      slave.sendHardwareCommand();
    }
    if (onStatusChanged != null) onStatusChanged!();
  }

  void setSmoke(bool isOn) {
    isSmokeOn = isOn;
    sendHardwareCommand();
    for (var slave in coupledControllers) {
      slave.isSmokeOn = isOn;
      slave.sendHardwareCommand();
    }
    if (onStatusChanged != null) onStatusChanged!();
  }

  void setGear(int gear, {bool forward = true}) {
    if (config.gears.containsKey(gear)) {
      double speed = config.gears[gear]!;
      _setTargetAndRamp(speed, forward: forward, isManual: false);
      _delegateSpeedToSlaves(speed.toInt(), forward);
    }
  }

  void setTargetSpeed(int targetPercent, {bool forward = true}) {
    _setTargetAndRamp(
      targetPercent.toDouble(),
      forward: forward,
      isManual: true,
    );
    _delegateSpeedToSlaves(targetPercent, forward);
  }

  void reapplyConsistSpeed() {
    if (!isConsistMaster) return;
    int currentTargetAbs = targetSpeed.abs().round();
    _delegateSpeedToSlaves(currentTargetAbs, lastDirForward);
  }

  void _delegateSpeedToSlaves(int speedPercent, bool forward) {
    for (final unit in config.coupledUnits) {
      for (final slave in coupledControllers) {
        if (slave.config.id == unit.locoId && slave.isRunning) {
          bool effectiveForward = unit.isReversed ? !forward : forward;
          int trimmedSpeed = (speedPercent * (1.0 + unit.trim / 100.0)).round().clamp(0, 100);
          slave.setTargetSpeed(trimmedSpeed, forward: effectiveForward);
        }
      }
    }
  }

  // DAS ZENTRALE GEHIRN (RAMPING)
  void _setTargetAndRamp(
    double speedInput, {
    required bool forward,
    required bool isManual,
  }) {
    if (!isRunning) return;

    if (speedInput > 0) lastDirForward = forward;

    double absTarget = speedInput.abs();
    targetSpeed = forward ? absTarget : -absTarget;

    double activeRampStep =
        (useRampingProfile2 ? config.rampStep2 : config.rampStep).toDouble();
    double activeBrakeStep =
        (useRampingProfile2 ? config.brakeStep2 : config.brakeStep).toDouble();
    int activeRampDelay = useRampingProfile2
        ? config.rampDelay2
        : config.rampDelay;

    double minSpeed = config.vMin.toDouble();

    if (absTarget > config.vMax) {
      absTarget = config.vMax.toDouble();
    }

    _centralRampingTimer?.cancel();

    _centralRampingTimer = Timer.periodic(
      Duration(milliseconds: activeRampDelay),
      (timer) {
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
            currentSpeed = (currentSpeed + step > effectiveTarget)
                ? effectiveTarget
                : currentSpeed + step;
          }
        } else if (currentSpeed > effectiveTarget) {
          if (currentSpeed == 0 && effectiveTarget < 0) {
            // Gleiches gilt für Rückwärtsfahrt
            currentSpeed = (minSpeed > 0) ? -minSpeed : -step;
          } else {
            currentSpeed = (currentSpeed - step < effectiveTarget)
                ? effectiveTarget
                : currentSpeed - step;
          }
        }

        if (effectiveTarget == 0 && currentSpeed.abs() < step) {
          currentSpeed = 0;
        }

        sendHardwareCommand();
        if (onStatusChanged != null) onStatusChanged!();
      },
    );
  }

  void sendHardwareCommand();

  void emergencyStop() {
    targetSpeed = 0.0;
    currentSpeed = 0.0;
    _centralRampingTimer?.cancel();
    sendHardwareCommand();
    for (var slave in coupledControllers) {
      slave.emergencyStop();
    }
    if (onStatusChanged != null) onStatusChanged!();
  }

  void setLight(String port, bool isOn) {
    togglePortLight(port, isOn);
  }

  Future<void> disconnect() async {
    isRunning = false;
    _centralRampingTimer?.cancel();
    _lightFadeTimer?.cancel();
    _lightFadeTimer = null;
    batteryLevel = null;
    currentSpeed = 0.0;
    targetSpeed = 0.0;

    await device?.disconnect();
    onStatusChanged?.call();
  }

  Future<void> connectAndInitialize();
  Future<void> senderLoop();
}
