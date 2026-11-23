import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; 
import 'train_controller.dart';

class CircuitCubeController extends TrainController {
  Timer? _batteryPollTimer;
  static const List<String> _queryCandidates = [
    'b',
    '?',
    'v',
    'B',
    'V',
    'b\n',
    'v\n',
    'bat\n',
  ];
  String? _workingBatteryCmd;
  int _queryIndex = 0;

  // Glättung & Tiefpassfilter für 1S-LiPo unter Last
  double? _filteredBatteryLevel;

  // GATT-Write-Serialisierung gegen GATT_BUSY / Kollisionen
  bool _isWriting = false;
  final List<List<int>> _writeQueue = [];

  CircuitCubeController(super.config);

  @override
  Future<void> connectAndInitialize() async {
    device = BluetoothDevice.fromId(config.mac);

    device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && isRunning) {
        isRunning = false;
        _batteryPollTimer?.cancel();
        _workingBatteryCmd = null;
        _queryIndex = 0;
        _filteredBatteryLevel = null;
        _writeQueue.clear();
        _isWriting = false;
        onStatusChanged?.call();
      }
    });

    int attempts = 0;
    while (attempts < 3) {
      try {
        attempts++;
        await device!.connect(timeout: const Duration(seconds: 8), autoConnect: false);
        break;
      } catch (e) {
        if (attempts >= 3) rethrow;
        debugPrint("[CircuitCube] Verbindungsversuch $attempts fehlgeschlagen ($e), erneuter Versuch in 500ms...");
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    List<BluetoothService> services = await device!.discoverServices();

    for (var s in services) {
      debugPrint("[CircuitCube] Service entdeckt: ${s.uuid}");
      for (var c in s.characteristics) {
        debugPrint("[CircuitCube]   Char: ${c.uuid} (read: ${c.properties.read}, notify: ${c.properties.notify}, write: ${c.properties.write})");

        // 1. Offizieller Bluetooth Battery Service (0x180F / 0x2A19) oder separate 0x2A19 Characteristic
        // HINWEIS: Bei vielen Circuit Cubes liefert 2A19 nur einen 0% Dummy-Wert aus dem Nordic-SDK-Template.
        // Die echte Telemetrie kommt über Nordic UART 'b'. Daher Werte von 0% verwerfen!
        if (c.uuid.toString().toLowerCase().contains("2a19") ||
            s.uuid.toString().toLowerCase().contains("180f")) {
          debugPrint("[CircuitCube] Akku-Char gefunden: ${c.uuid}");
          if (c.properties.notify) {
            try {
              await c.setNotifyValue(true);
              c.onValueReceived.listen((val) {
                if (val.isNotEmpty && val[0] > 0 && val[0] <= 100) {
                  _updateBatteryLevel(val[0]);
                  debugPrint("[CircuitCube] Akku über BLE 0x2A19 Notify empfangen: $batteryLevel%");
                }
              });
            } catch (e) {
              debugPrint("[CircuitCube] Fehler beim Aktivieren von Notify auf 0x2A19: $e");
            }
          }
          if (c.properties.read) {
            try {
              List<int> initial = await c.read();
              if (initial.isNotEmpty && initial[0] > 0 && initial[0] <= 100) {
                _updateBatteryLevel(initial[0]);
                debugPrint("[CircuitCube] Akku über BLE 0x2A19 Read empfangen: $batteryLevel%");
              }
            } catch (e) {
              debugPrint("[CircuitCube] Fehler beim Lesen von 0x2A19: $e");
            }
          }
        }

        // 2. Nordic UART Service (6e400001)
        if (s.uuid.toString().toLowerCase().contains("6e400001")) {
          if (c.uuid.toString().toLowerCase().contains("6e400002")) {
            writeCharacteristic = c;
          } else if (c.uuid.toString().toLowerCase().contains("6e400003")) {
            try {
              await c.setNotifyValue(true);
              c.onValueReceived.listen((data) {
                _parseCircuitCubeResponse(data);
              });
              debugPrint("[CircuitCube] Nordic UART TX (6e400003) Benachrichtigungen aktiv");
            } catch (e) {
              debugPrint("[CircuitCube] Fehler beim Aktivieren von 6e400003 Notify: $e");
            }
          }
        }
      }
    }

    if (writeCharacteristic != null) {
      isRunning = true;
      onStatusChanged?.call();

      // Start der Abfragen: zunächst in schneller Suchphase (alle 4 Sekunden)
      _setupBatteryPollTimer(interval: const Duration(seconds: 4));

      // Erste Abfrage mit 800 ms Verzögerung starten, damit die initialen Motor-Befehle ungestört durchgehen
      Future.delayed(const Duration(milliseconds: 800), () {
        if (batteryLevel == null && isRunning) {
          _sendNextBatteryQuery();
        }
      });
    }
  }

  void _setupBatteryPollTimer({required Duration interval}) {
    _batteryPollTimer?.cancel();
    _batteryPollTimer = Timer.periodic(interval, (_) {
      _sendNextBatteryQuery();
    });
  }

  // Sequenzielles Schreiben über eine Queue verhindert GATT_BUSY / Schreibkollisionen
  Future<void> _safeWrite(List<int> bytes) async {
    if (writeCharacteristic == null || !isRunning) return;
    _writeQueue.add(bytes);
    if (_isWriting) return;

    _isWriting = true;
    while (_writeQueue.isNotEmpty && isRunning) {
      final next = _writeQueue.removeAt(0);
      try {
        await writeCharacteristic!.write(next, withoutResponse: true);
        // Minimaler Puffer zwischen Writes entlastet den BLE-Stack
        await Future.delayed(const Duration(milliseconds: 15));
      } catch (e) {
        debugPrint("[CircuitCube] Fehler beim Senden: $e");
      }
    }
    _isWriting = false;
  }

  void _sendNextBatteryQuery() {
    if (writeCharacteristic == null || !isRunning) return;
    final cmd = _workingBatteryCmd ?? _queryCandidates[_queryIndex % _queryCandidates.length];
    _queryIndex++;
    try {
      debugPrint("[CircuitCube] Sende Akku-Abfrage: '$cmd'");
      _safeWrite(utf8.encode(cmd));
    } catch (e) {
      debugPrint("[CircuitCube] Fehler beim Einreihen der Abfrage '$cmd': $e");
    }
  }

  void _updateBatteryLevel(int rawPercentage) {
    if (rawPercentage <= 0) return; // 0% Dummy-Werte verwerfen

    // Bei Erstinitialisierung oder unplausiblem Startsprung direkt übernehmen
    if (_filteredBatteryLevel == null || (_filteredBatteryLevel! <= 5 && rawPercentage > 20)) {
      _filteredBatteryLevel = rawPercentage.toDouble();
    } else {
      // Unter Last (currentSpeed != 0) dämpfen wir Spannungseinbrüche stärker ab (alpha = 0.05),
      // im Stillstand reagiert der Filter zügiger (alpha = 0.20).
      final double alpha = (currentSpeed != 0) ? 0.05 : 0.20;
      _filteredBatteryLevel = alpha * rawPercentage + (1.0 - alpha) * _filteredBatteryLevel!;
    }

    final int rounded = _filteredBatteryLevel!.round().clamp(0, 100);
    // Hysterese: Aktualisierung bei mindestens 2% Abweichung oder wenn noch kein Wert vorliegt
    if (batteryLevel == null || (rounded - batteryLevel!).abs() >= 2) {
      batteryLevel = rounded;
      debugPrint("[CircuitCube] Neuer Akkustand gesetzt: $batteryLevel% (Roh: $rawPercentage%, Speed: $currentSpeed)");
      onStatusChanged?.call();
    }
  }

  void _parseCircuitCubeResponse(List<int> data) {
    if (data.isEmpty) return;

    String text = String.fromCharCodes(data).trim();
    debugPrint("[CircuitCube] RX (${data.length}b): hex=${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')} text='$text'");

    int? newBattery;

    // 1. Binäre Telemetrie-Auswertung:
    if (data.length == 1) {
      // Einzelnes Byte: Prozentwert 15-100 (ausgeschlossen Steuerzeichen wie \n=10, \r=13)
      int val = data[0];
      if (val >= 15 && val <= 100 && val != 10 && val != 13) {
        newBattery = val;
      }
    } else if (data.length >= 2) {
      // 16-Bit Little-Endian oder Big-Endian Spannung in mV (3000 - 4350 mV für 1S LiPo)
      int leMv = data[0] + (data[1] << 8);
      int beMv = (data[0] << 8) + data[1];
      int mv = (leMv >= 3000 && leMv <= 4350)
          ? leMv
          : ((beMv >= 3000 && beMv <= 4350) ? beMv : 0);
      if (mv > 0) {
        newBattery = (((mv - 3300) / (4200 - 3300)) * 100.0).round().clamp(0, 100);
      } else if (data[0] == 0x42 || data[0] == 0x56) {
        // 'B' oder 'V' gefolgt von Prozentwert (Byte 1)
        if (data[1] >= 1 && data[1] <= 100) {
          newBattery = data[1];
        }
      }
    }

    // 2. Textuelle Telemetrie-Auswertung (zeilenweise für den Fall mehrzeiliger Antworten):
    if (newBattery == null && text.isNotEmpty) {
      final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty);

      for (final line in lines) {
        // Motor-Befehlsechos (z.B. "+000a", "-128b", "+255c") ignorieren!
        if (RegExp(r'^[+-]\d{3}[abc]$', caseSensitive: false).hasMatch(line)) {
          continue;
        }

        // a) Spannung als Dezimalzahl: z. B. "3.85V", "3,85 V", "V: 3.85"
        final voltMatch = RegExp(r'(?:V|VOLT)?\s*[:=]?\s*(\d+)[.,](\d{1,3})\s*V?', caseSensitive: false).firstMatch(line);
        if (voltMatch != null) {
          double v = double.tryParse("${voltMatch.group(1)}.${voltMatch.group(2)}") ?? 0;
          if (v >= 3.0 && v <= 4.35) {
            newBattery = (((v - 3.3) / (4.2 - 3.3)) * 100.0).round().clamp(0, 100);
            break;
          }
        }

        // b) Millivolt oder Prozentwert mit/ohne Präfix (B:, BAT:, V:, ADC: oder Zahl)
        final numMatch = RegExp(r'(?:B|BAT|BATTERY|VOLT|V|ADC)?\s*[:=]?\s*([+-]?\d{1,5})\s*%?', caseSensitive: false).firstMatch(line);
        if (numMatch != null) {
          int? num = int.tryParse(numMatch.group(1)!);
          if (num != null) {
            num = num.abs();
            if (num >= 3000 && num <= 4350) {
              // Millivolt (z.B. 3850)
              newBattery = (((num - 3300) / (4200 - 3300)) * 100.0).round().clamp(0, 100);
              break;
            } else if (num >= 1 && num <= 100) {
              // Prozentwert (z.B. 85%)
              newBattery = num;
              break;
            }
          }
        }
      }
    }

    if (newBattery != null) {
      if (_workingBatteryCmd == null && _queryIndex > 0) {
        _workingBatteryCmd = _queryCandidates[(_queryIndex - 1) % _queryCandidates.length];
        debugPrint("[CircuitCube] Funktionierender Abfragebefehl erkannt: '$_workingBatteryCmd'");
        // Intervall auf 20 Sekunden strecken, um Nordic UART im laufenden Fahrbetrieb zu schonen
        _setupBatteryPollTimer(interval: const Duration(seconds: 20));
      }
      _updateBatteryLevel(newBattery);
    }
  }

  // Die Funktion, die den Prozentwert (-100 bis 100) in das Cube-Format umrechnet
  void _sendCommand(String channel, int speed) {
    if (writeCharacteristic == null || !isRunning) return;
    String dir = speed >= 0 ? "+" : "-";
    int cubeSpeed = ((speed.abs() / 100.0) * 255).round().clamp(0, 255);
    String command = "$dir${cubeSpeed.toString().padLeft(3, '0')}${channel.toLowerCase()}";
    
    _safeWrite(command.codeUnits);
  }

  // --- DIE ZENTRALE HARDWARE-METHODE ---
  @override
  void sendHardwareCommand() {
    if (writeCharacteristic == null || !isRunning) return;

    List<String> cubePorts = ['A', 'B', 'C'];

    for (String port in cubePorts) {
      String role = config.portSettings[port] ?? 'none';
      
      if (role != 'none') {
        int power = getPowerForRole(role, port);
        _sendCommand(port, power);
      } else {
        // Falls der Port explizit auf 'none' steht, zur Sicherheit auf 0 setzen
        _sendCommand(port, 0); 
      }
    }
  }

  @override
  Future<void> senderLoop() async {
    // Bleibt leer, da On-Demand
  }

  @override
  Future<void> disconnect() async {
    _batteryPollTimer?.cancel();
    _batteryPollTimer = null;
    _workingBatteryCmd = null;
    _queryIndex = 0;
    _filteredBatteryLevel = null;
    _writeQueue.clear();
    _isWriting = false;
    await super.disconnect();
  }
}
