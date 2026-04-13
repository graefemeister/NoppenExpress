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
  final String name;
  final String mac;
  final String protocol;
  final String imagePath;
  final String notes;
  final Map<int, double> gears;
  final double rampStep;
  final double rampStep2;
  final double brakeStep;
  final double brakeStep2;
  final double reverseLimit;
  final bool autoLight;
  final Map<String, String> portSettings;
  final int deltaStep; 
  final int rampDelay;
  final int rampDelay2;

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
    this.autoLight = true,
    this.portSettings = const {'A': 'motor', 'B': 'motor'},
    this.deltaStep = 10, 
    this.rampDelay = 100,
    this.rampDelay2 = 250,
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
      'autoLight': autoLight, 
      'portSettings': portSettings,
      'deltaStep': deltaStep, 
      'rampDelay': rampDelay,
      'rampDelay2': rampDelay2,
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
      autoLight: map['autoLight'] ?? false,
      portSettings: Map<String, String>.from(map['portSettings'] ?? {'A': 'motor', 'B': 'motor'}),
      deltaStep: map['deltaStep'] ?? 10, 
      rampDelay: map['rampDelay'] ?? 100,
      rampDelay2: map['rampDelay2'] ?? 250,
    );
  }
}

// --- 2. DIE ZENTRALE BASISKLASSE ---
abstract class TrainController {
  final TrainConfig config;
  bool isRunning = false;
  
  // NEU: Der Umschalter für das Profil!
  bool useRampingProfile2 = false; 
  
  double currentSpeed = 0.0; 
  double targetSpeed = 0.0;  
  Timer? _centralRampingTimer;

  bool inverted = false;
  bool lastDirForward = true;
  int lightA = 0; int lightB = 0; int lightC = 0;

  BluetoothDevice? device;
  BluetoothCharacteristic? writeCharacteristic;
  VoidCallback? onStatusChanged;

  TrainController(this.config);

  String get name => config.name;
  String get mac => config.mac;
  String get imagePath => config.imagePath;

  void toggleInverted() { inverted = !inverted; }

  void setGear(int gear, {bool forward = true}) {
    if (config.gears.containsKey(gear)) {
      double speed = config.gears[gear]!;
      _setTargetAndRamp(speed, forward: forward, isManual: false);
    }
  }

  void setTargetSpeed(int targetPercent, {bool forward = true}) {
    _setTargetAndRamp(targetPercent.toDouble(), forward: forward, isManual: true);
  }

  // --- DAS ZENTRALE GEHIRN FÜR BEIDE PULTE ---
  void _setTargetAndRamp(double speedTarget, {required bool forward, required bool isManual}) {
    if (!isRunning) return;

    bool actualForward = inverted ? !forward : forward;
    if (speedTarget > 0) lastDirForward = forward;
    
    double finalSpeed = speedTarget;
    if (!actualForward && config.reverseLimit < 1.0) {
      finalSpeed *= config.reverseLimit;
    }
    targetSpeed = actualForward ? finalSpeed : -finalSpeed;

    if (config.autoLight) updateAutoLight();

    // HIER PASSIERT DIE MAGIE: Wir wählen die Werte anhand des Schalters!
    double activeRampStep = useRampingProfile2 ? config.rampStep2 : config.rampStep;
    double activeBrakeStep = useRampingProfile2 ? config.brakeStep2 : config.brakeStep;
    int activeRampDelay = useRampingProfile2 ? config.rampDelay2 : config.rampDelay;

    bool isAccelerating = targetSpeed.abs() > currentSpeed.abs();

    double step = isManual ? config.deltaStep.toDouble() : (isAccelerating ? activeRampStep : activeBrakeStep);
    int accMs = isManual ? activeRampDelay : 100; 
    double minSpeed = config.gears[1] ?? 25.0;     

    _centralRampingTimer?.cancel();
    
    _centralRampingTimer = Timer.periodic(Duration(milliseconds: accMs), (timer) {
      if (currentSpeed == targetSpeed) {
        timer.cancel();
        return;
      }

      if (currentSpeed < targetSpeed) {
        // Nur auf V1 springen, wenn wir NICHT im manuellen Modus sind
        if (!isManual && currentSpeed == 0 && targetSpeed > 0) {
          currentSpeed = minSpeed; 
        } else {
          currentSpeed = (currentSpeed + step > targetSpeed) ? targetSpeed : currentSpeed + step;
        }
      } else if (currentSpeed > targetSpeed) {
        // Nur auf -V1 springen, wenn wir NICHT im manuellen Modus sind
        if (!isManual && currentSpeed == 0 && targetSpeed < 0) {
          currentSpeed = -minSpeed; 
        } else {
          currentSpeed = (currentSpeed - step < targetSpeed) ? targetSpeed : currentSpeed - step;
        }
      }

      sendHardwareCommand();
      if (onStatusChanged != null) onStatusChanged!();
    });
  }

  // --- NEU: DIE ABSTRAKTE METHODE FÜR DIE HARDWARE ---
  // Jeder Controller muss nun diese Methode implementieren und 
  // einfach nur `currentSpeed` funken!
  void sendHardwareCommand();

  void emergencyStop() { 
    targetSpeed = 0.0; 
    currentSpeed = 0.0; 
    _centralRampingTimer?.cancel();
    sendHardwareCommand(); // Stopp sofort an Lok funken
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