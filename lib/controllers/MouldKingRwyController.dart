import 'train_controller.dart';
import 'dart:typed_data';           
import 'package:flutter/services.dart'; 
import 'package:flutter/foundation.dart';
import 'dart:async';

class MouldKingRwyController extends TrainController {
  bool isRunning = false;
  double _actualSpeed = 0.0;
  
  static const platform = MethodChannel('com.noppenexpress/ble_native');
  void Function()? onStatusChanged;

  MouldKingRwyController(TrainConfig config) : super(config);

  @override
  void setLight(String port, bool isOn) {
    // Hier können wir später die Licht-Bytes einbauen
  }

  @override
  void updateAutoLight() { }

  @override
  Future<void> connectAndInitialize() async {
    isRunning = true;
    onStatusChanged?.call();
    senderLoop();
  }

  @override
  Future<void> senderLoop() async {
    while (isRunning) {
      double target = targetSpeed;
      double step = (target.abs() > _actualSpeed.abs()) ? config.rampStep : 3.0;
      
      if (_actualSpeed == 0 && target != 0) _actualSpeed = target > 0 ? 20.0 : -20.0;
      
      if (_actualSpeed < target) {
        _actualSpeed = (_actualSpeed + step > target) ? target : _actualSpeed + step;
      } else if (_actualSpeed > target) {
        _actualSpeed = (_actualSpeed - step < target) ? target : _actualSpeed - step;
      }

      // Die Checksummen-Pärchen, die wir im Log gefunden haben
      int sByte; int cs1; int cs2;
      
      if (_actualSpeed.abs() < 5) {
        sByte = 0x51; // STOP (aus nRF Log)
        cs1 = 0x75; cs2 = 0xEC;
      } else {
        sByte = 0xD1; // VOLLGAS (aus nRF Log)
        cs1 = 0x1B; cs2 = 0xC1;
      }
      
      // Das MUSS gesendet werden, damit der Zug reagiert (24 Bytes)
      List<int> bytes = [
        0x6D, 0xB6, 0x43, 0xCF, 0x7E, 0x8F, 0x47, 0x11, 
        0x83, 0xDE, 0x5B, 0x38, 
        sByte,                // Hier landet unser Speed-Byte
        0x7A, 0xAA, 0x2D, 
        cs1, cs2,             // Hier landet die passende Checksumme
        0x13, 0x14, 0x15, 0x16, 0x17, 0x18
      ];

      try {
        await platform.invokeMethod('startDinoAdvertising', { 
          'payload': Uint8List.fromList(bytes),
          'companyId': 0xFFF0, // ZWINGEND für den neuen Zug
          'connectable': true, // Erzeugt die Flags 02 01 02
          'scannable': true,   
        });
      } on PlatformException catch (e) {
        debugPrint("Native Fehler: ${e.message}");
      }
      
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  void emergencyStop() {
    _actualSpeed = 0.0;
    targetSpeed = 0.0;
  }
  
  @override
  Future<void> disconnect() async {
    isRunning = false;
    onStatusChanged?.call();
    try {
      await platform.invokeMethod('stopDinoAdvertising');
    } catch(e) {}
  }

  @override
  void sendHardwareCommand() {
    // Hier kommt später der Funk-Befehl rein.
    // Für Züge mit eigener Sende-Schleife (Heartbeat) bleibt das evtl. sogar leer.
  }

  
}