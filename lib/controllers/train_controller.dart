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