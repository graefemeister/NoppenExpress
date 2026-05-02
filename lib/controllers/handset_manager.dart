import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'train_controller.dart'; // Passe den Pfad an, falls nötig

class HandsetManager {
  // --- SINGLETON SETUP ---
  // Stellt sicher, dass die ganze App nur EINE Instanz des Managers nutzt
  static final HandsetManager instance = HandsetManager._internal();
  HandsetManager._internal();

  Function(TrainController)? onTrainFocused;
  
  // --- BLE VARIABLEN ---
  BluetoothDevice? _device;
  BluetoothCharacteristic? _lpf2Characteristic;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  
  // Die standardmäßige LPF2 UUID für alle LEGO Hubs
  final String _lpf2Uuid = "00001624-1212-efde-1623-785feabcd123";

  // --- STATE VARIABLEN ---
  List<TrainController> activeTrains = [];
  int _focusedTrainIndex = 0;
  final double speedIncrement = 10.0; // Geschwindigkeitsschritt pro Klick

  // LED Farben-Mapping für die Zug-Indizes (0-8)
  static const List<int> trainColors = [
    3,  // 0: Blue (Blau)
    7,  // 1: Yellow (Gelb)
    1,  // 2: Pink
    6,  // 3: Green (Grün)
    2,  // 4: Purple (Lila)
    8,  // 5: Orange
    4,  // 6: Light Blue (Hellblau)
    10, // 7: White (Weiß)
    5,  // 8: Cyan (Türkis)
  ];

  // --- 1. VERBINDUNGS-MANAGEMENT ---

  Future<void> connect(BluetoothDevice device) async {
    _device = device;

    // Überwache Verbindungsabbrüche
    _connSub = _device!.connectionState.listen((BluetoothConnectionState state) {
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint("Handset getrennt.");
        _cleanup();
      }
    });

    try {
      // Services abrufen
      List<BluetoothService> services = await _device!.discoverServices();
      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.uuid.toString() == _lpf2Uuid) {
            _lpf2Characteristic = char;
            
            // Benachrichtigungen aktivieren, um Tastendrücke zu empfangen
            await _lpf2Characteristic!.setNotifyValue(true);
            _notifySub = _lpf2Characteristic!.onValueReceived.listen(_onNotificationReceived);
            
            // Ports der Fernbedienung konfigurieren
            await _setupPorts();
            
            // Initiale LED-Farbe setzen
            _updateLedColor();
            
            debugPrint("Handset erfolgreich initialisiert!");
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Fehler bei Handset-Initialisierung: $e");
    }
  }

  Future<void> disconnect() async {
    if (_device != null) {
      await _device!.disconnect();
    }
    _cleanup();
  }

  void _cleanup() {
    _notifySub?.cancel();
    _connSub?.cancel();
    _lpf2Characteristic = null;
    _device = null;
  }

  bool get isConnected => _device != null && _lpf2Characteristic != null;

  // --- 2. SETUP & HARDWARE KOMMUNIKATION ---

  Future<void> _setupPorts() async {
    if (_lpf2Characteristic == null) return;

    // Setup Kommando Port 0 (Links): Mode 0, Delta 1, Notifications Enable
    List<int> setupPort0 = [0x0A, 0x00, 0x41, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01];
    // Setup Kommando Port 1 (Rechts): Mode 0, Delta 1, Notifications Enable
    List<int> setupPort1 = [0x0A, 0x00, 0x41, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01];

    try {
      await _lpf2Characteristic!.write(setupPort0, withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 100)); // Kurze Pause für den Hub
      await _lpf2Characteristic!.write(setupPort1, withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint("Fehler beim Port-Setup: $e");
    }
  }

  void _updateLedColor() {
    if (_lpf2Characteristic == null) return;
    
    // Wenn die Liste leer ist (keine Züge an), leuchtet die LED Rot (9).
    // Das signalisiert: "Ich bin da, aber die Schienen sind leer."
    int colorCode = activeTrains.isEmpty ? 9 : trainColors[_focusedTrainIndex % trainColors.length];
    
    // Kommando an Port 0x34 (52 - die interne RGB LED)
    List<int> ledCmd = [0x08, 0x00, 0x81, 0x34, 0x11, 0x51, 0x00, colorCode];
    
    try {
      _lpf2Characteristic!.write(ledCmd, withoutResponse: true);
    } catch (e) {
      debugPrint("Fehler beim LED Update: $e");
    }
  }

  // --- 3. STATE UPDATE (Von außen aufzurufen) ---

  /// Wird von deinem Main-Screen aufgerufen, wenn Züge hinzugefügt/entfernt werden
  void updateTrains(List<TrainController> allTrains) {
    // Wir filtern die Liste: Nur Loks, bei denen isRunning == true ist
    activeTrains = allTrains.where((t) => t.isRunning).toList();
    
    // Sicherstellen, dass der Fokus nicht ins Leere greift
    if (activeTrains.isNotEmpty) {
      if (_focusedTrainIndex >= activeTrains.length) {
        _focusedTrainIndex = 0;
      }
    } else {
      _focusedTrainIndex = 0;
    }
    
    if (isConnected) _updateLedColor();
  }

  // --- 4. EVENT PARSING & LOGIK ---

  void _onNotificationReceived(List<int> data) {
    // Ein "Port Value (Single) Feedback" hat immer MsgType 0x45
    if (data.length >= 5 && data[2] == 0x45) {
      int port = data[3];
      
      // Byte 4 ist der Tastenzustand (als Signed Int). Wir wandeln >127 in Negative um.
      int buttonState = data[4]; 
      if (buttonState > 127) buttonState -= 256; 

      // 0 bedeutet "Taste losgelassen" -> Ignorieren wir für Tap-Aktionen
      if (buttonState == 0) return;

      if (port == 0x00) { // Linke Seite: Geschwindigkeit
        _handleSpeedCommand(buttonState);
      } else if (port == 0x01) { // Rechte Seite: Lok-Auswahl
        _handleSelectorCommand(buttonState);
      }
    }
  }

  void _handleSpeedCommand(int state) {
    if (activeTrains.isEmpty) return;
    if (_focusedTrainIndex >= activeTrains.length) _focusedTrainIndex = 0;
    
    TrainController focusedTrain = activeTrains[_focusedTrainIndex];

    if (state == 1) { // Plus Button (+)
      // Neue Zielgeschwindigkeit berechnen (-100 bis +100)
      double newSpeed = (focusedTrain.targetSpeed + speedIncrement).clamp(-100.0, 100.0);
      // Den TrainController offiziell anweisen (startet den Ramping-Timer!)
      focusedTrain.setTargetSpeed(newSpeed.abs().toInt(), forward: newSpeed >= 0);
    } 
    else if (state == -1) { // Minus Button (-)
      double newSpeed = (focusedTrain.targetSpeed - speedIncrement).clamp(-100.0, 100.0);
      focusedTrain.setTargetSpeed(newSpeed.abs().toInt(), forward: newSpeed >= 0);
    } 
    else if (state == 127 || state == -127) { // Roter Button (Stop)
      focusedTrain.emergencyStop();
    }
  }

  void _handleSelectorCommand(int state) {
    if (activeTrains.isEmpty) return;

    if (state == 1) { // Plus Button -> Nächster Zug
      _focusedTrainIndex = (_focusedTrainIndex + 1) % activeTrains.length;
      _updateLedColor();
      onTrainFocused?.call(activeTrains[_focusedTrainIndex]);
    } 
    else if (state == -1) { // Minus Button -> Vorheriger Zug
      _focusedTrainIndex = (_focusedTrainIndex - 1 + activeTrains.length) % activeTrains.length;
      _updateLedColor();
      onTrainFocused?.call(activeTrains[_focusedTrainIndex]);
    } 
    else if (state == 127 || state == -127) { // Roter Button -> NOTHALT FÜR ALLE
      for (var train in activeTrains) {
        train.targetSpeed = 0.0;
        train.emergencyStop();
      }
    }
  }
}