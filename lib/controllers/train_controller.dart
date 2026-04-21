import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import '../mould_king_40_protocol.dart'; 
import '../train_manager.dart';

// --- 1. DIE DATENSTRUKTUR ---
class TrainConfig {
  final String id;
  final String mac;
  final String protocol;
  String name;
  String notes;
  Map<int, double> gears;
  double rampStep;
  double rampStep2;
  double brakeStep;
  double brakeStep2;
  double reverseLimit;
  bool inverted;
  bool autoLight;
  Map<String, String> portSettings;
  int deltaStep; 
  int rampDelay;
  int rampDelay2;
  bool isManualMode;
  bool useRampingProfile2;
  String imagePath;


  TrainConfig({
    required this.id,
    required this.name,
    required this.mac,
    required this.protocol,
    this.imagePath = "",
    this.notes = "",
    this.gears = const {0: 0, 1: 25, 2: 50, 3: 75, 4: 100},
    this.rampStep = 1.0,
    this.rampStep2 = 0.3,
    this.brakeStep = 3.0,
    this.brakeStep2 = 1.0,
    this.reverseLimit = 1.0,
    this.inverted = false,
    this.autoLight = false,
    this.portSettings = const {'A': 'motor', 'B': 'motor'},
    this.deltaStep = 10, 
    this.rampDelay = 100,
    this.rampDelay2 = 250,
    this.isManualMode = false,
    this.useRampingProfile2 = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'name': name, 'mac': mac, 'protocol': protocol,
      'imagePath': imagePath, 'notes': notes,
      'gears': gears.map((k, v) => MapEntry(k.toString(), v)),
      'rampStep': rampStep,
      'rampStep2': rampStep2, 
      'brakeStep': brakeStep,
      'brakeStep2': brakeStep2,
      'reverseLimit': reverseLimit,
      'inverted': inverted,
      'autoLight': autoLight, 
      'portSettings': portSettings,
      'deltaStep': deltaStep, 
      'rampDelay': rampDelay,
      'rampDelay2': rampDelay2,
      'useRampingProfile2': useRampingProfile2,
      'isManualMode': isManualMode, 
    };
  }

  factory TrainConfig.fromMap(Map<String, dynamic> map) {
    return TrainConfig(
      id: map['id'], name: map['name'], mac: map['mac'], protocol: map['protocol'],
      imagePath: map['imagePath'] ?? "", notes: map['notes'] ?? "",
      gears: (map['gears'] as Map).map((k, v) => MapEntry(int.parse(k), v.toDouble())),
      rampStep: (map['rampStep'] ?? 1.0).toDouble(),
      rampStep2: (map['rampStep2'] ?? 0.3).toDouble(),
      brakeStep: (map['brakeStep'] ?? 3.0).toDouble(),
      brakeStep2: (map['brakeStep2'] ?? 1.0).toDouble(),
      reverseLimit: (map['reverseLimit'] ?? 1.0).toDouble(),
      inverted: map['inverted'] ?? false,
      autoLight: map['autoLight'] ?? false,
      portSettings: Map<String, String>.from(map['portSettings'] ?? {'A': 'motor', 'B': 'motor'}),
      deltaStep: map['deltaStep'] ?? 10, 
      rampDelay: map['rampDelay'] ?? 100,
      rampDelay2: map['rampDelay2'] ?? 250,
      useRampingProfile2: map['useRampingProfile2'] ?? false,
      isManualMode: map['isManualMode'] ?? false,
    );
  }
}

// --- 2. DIE ZENTRALE BASISKLASSE ---
abstract class TrainController {
TrainConfig config;
  bool isRunning = false;
  
  // Diese Getters sind super! Sie greifen immer auf die AKTUELL hinterlegte 
  // 'config' zu. Wenn wir 'config' tauschen, liefern sie sofort den neuen Wert.
  bool get useRampingProfile2 => config.useRampingProfile2; 
  bool get inverted => config.inverted;
  String get name => config.name;
  String get mac => config.mac;
  String get imagePath => config.imagePath;

  double currentSpeed = 0.0; 
  double targetSpeed = 0.0;  
  Timer? _centralRampingTimer;

  bool lastDirForward = true;
  int lightA = 0; int lightB = 0; int lightC = 0;

  BluetoothDevice? device;
  BluetoothCharacteristic? writeCharacteristic;
  VoidCallback? onStatusChanged;

  // Konstruktor (jetzt ohne final)
  TrainController(this.config);

  // --- DER ENTSCHEIDENDE NEUE TEIL ---
  
  /// Aktualisiert die Konfiguration "fliegend", ohne den Controller 
  /// oder die Bluetooth-Verbindung zu unterbrechen.
  void updateConfig(TrainConfig newConfig) {
    // Falls die ID nicht passt, sollten wir vorsichtig sein
    if (config.id != newConfig.id) {
      print("Warnung: Config-Update für eine andere Lok-ID!");
    }
    
    config = newConfig;
    
    // Optional: Triggert die UI-Aktualisierung (falls ein Listener dran hängt)
    if (onStatusChanged != null) {
      onStatusChanged!();
    }
    
    print("Konfiguration für '$name' im laufenden Betrieb aktualisiert.");
  }

  // Setzt eine feste Fahrstufe (0-4)
  void setGear(int gear, {bool forward = true}) {
    if (config.gears.containsKey(gear)) {
      double speed = config.gears[gear]!;
      _setTargetAndRamp(speed, forward: forward, isManual: false);
    }
  }

  // Manuelle Steuerung (+/- Buttons)
  void setTargetSpeed(int targetPercent, {bool forward = true}) {
    // Wir übergeben den positiven Prozentwert und die Richtung
    _setTargetAndRamp(targetPercent.toDouble(), forward: forward, isManual: true);
  }

  // --- DAS ZENTRALE GEHIRN ---
  void _setTargetAndRamp(double speedInput, {required bool forward, required bool isManual}) {
    if (!isRunning) return;

    // 1. Richtung merken für Hilfsfunktionen (z.B. Licht)
    if (speedInput > 0) lastDirForward = forward;
    
    // 2. Limit für Rückwärtsfahrt berechnen
    double absTarget = speedInput.abs(); 
    if (!forward && config.reverseLimit < 1.0) {
      absTarget *= config.reverseLimit;
    }

    // 3. Logischer Zielwert für die Mathematik (-100.0 bis +100.0)
    // Dies ist die Basis für alle Berechnungen im Timer.
    targetSpeed = forward ? absTarget : -absTarget;

    if (config.autoLight) updateAutoLight();

    // 4. Dynamische Parameter aus dem gewählten Profil laden
    double activeRampStep = useRampingProfile2 ? config.rampStep2 : config.rampStep;
    double activeBrakeStep = useRampingProfile2 ? config.brakeStep2 : config.brakeStep;
    int activeRampDelay = useRampingProfile2 ? config.rampDelay2 : config.rampDelay;
    double minSpeed = (config.gears[1] ?? 25.0).toDouble();

    _centralRampingTimer?.cancel();
    
    _centralRampingTimer = Timer.periodic(Duration(milliseconds: activeRampDelay), (timer) {
      if (currentSpeed == targetSpeed) {
        timer.cancel();
        return;
      }

      // Beschleunigen wir (weg von 0) oder bremsen wir (hin zu 0)?
      bool isAccelerating = targetSpeed.abs() > currentSpeed.abs();
      double step = isAccelerating ? activeRampStep : activeBrakeStep;

      // "Einrast"-Punkt: Alles zwischen 1 und minSpeed wird als minSpeed behandelt
      double effectiveTarget = targetSpeed;
      if (targetSpeed.abs() > 0 && targetSpeed.abs() < minSpeed) {
        effectiveTarget = (targetSpeed > 0) ? minSpeed : -minSpeed;
      }

      // --- RAMPING LOGIK ---
      if (currentSpeed < effectiveTarget) {
        // Wir müssen den Wert erhöhen (Richtung Plus)
        if (currentSpeed == 0 && effectiveTarget > 0) {
          currentSpeed = minSpeed; // Sofort-Start auf minSpeed
        } else {
          currentSpeed = (currentSpeed + step > effectiveTarget) ? effectiveTarget : currentSpeed + step;
        }
      } else if (currentSpeed > effectiveTarget) {
        // Wir müssen den Wert verringern (Richtung Minus)
        if (currentSpeed == 0 && effectiveTarget < 0) {
          currentSpeed = -minSpeed; // Sofort-Start rückwärts auf minSpeed
        } else {
          currentSpeed = (currentSpeed - step < effectiveTarget) ? effectiveTarget : currentSpeed - step;
        }
      }

      // Null-Punkt "Snap": Verhindert unendliches Ramping bei kleinsten Restwerten
      if (effectiveTarget == 0 && currentSpeed.abs() < step) {
        currentSpeed = 0;
      }

      sendHardwareCommand();
      if (onStatusChanged != null) onStatusChanged!();
    });
  }

  // Diese Methode muss in den Unterklassen (z.B. MouldKingController) 
  // implementiert werden und die Invertierung berücksichtigen!
  void sendHardwareCommand();

  void emergencyStop() { 
    targetSpeed = 0.0; 
    currentSpeed = 0.0; 
    _centralRampingTimer?.cancel();
    sendHardwareCommand(); 
    updateAutoLight(); 
    if (onStatusChanged != null) onStatusChanged!();
  }
  
  void setLight(String port, bool isOn);

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
  void updateAutoLight(); 
}