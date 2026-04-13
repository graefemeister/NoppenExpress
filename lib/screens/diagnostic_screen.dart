import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class UniversalDiagnosticScreen extends StatefulWidget {
  const UniversalDiagnosticScreen({Key? key}) : super(key: key);
  @override
  State<UniversalDiagnosticScreen> createState() => _UniversalDiagnosticScreenState();
}

class FoundConfig {
  final String name;
  final BluetoothCharacteristic char;
  final String cmd;
  final String stopCmd;
  final bool isHex;
  final bool useAck;
  FoundConfig({required this.name, required this.char, required this.cmd, required this.stopCmd, required this.isHex, required this.useAck});
}

class TestResult {
  final String configName;
  final bool success;
  final String time = DateTime.now().toString().substring(11, 19);
  TestResult(this.configName, this.success);
  Map<String, dynamic> toJson() => {'protocol': configName, 'success': success, 'time': time};
}

class _UniversalDiagnosticScreenState extends State<UniversalDiagnosticScreen> {
  BluetoothDevice? _device;
  List<BluetoothCharacteristic> _writeableChars = [];
  bool _isConnected = false;
  bool _isScanning = false;
  bool _isAutoProbing = false;
  bool _isAutoTesting = false;
  int _currentTestIndex = 0;

  final List<FoundConfig> _foundConfigs = [];
  final List<TestResult> _testHistory = [];
  final List<String> _consoleLogs = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _driveTimer;

  // NEUE PROTOKOLL-STRATEGIE: Fokus auf kurze Pakete
  final List<Map<String, dynamic>> _protocols = [
    // 1. MouldKing Kurz (oft bei Railway-Hubs)
    {'name': 'MK Short Port A', 'cmd': 'T051W', 'stop': 'T050W', 'hex': false},
    
    // 2. MouldKing Railway v2 (Header 01 + Kurz-ASCII)
    {'name': 'MK Train Short (Port A)', 'cmd': '01 54 30 35 31 57', 'stop': '01 54 30 35 30 57', 'hex': true},
    
    // 3. MouldKing 6-Kanal (Binär-Modus)
    {'name': 'MK 6CH Bin A', 'cmd': '01 01 64', 'stop': '01 01 00', 'hex': true},
    
    // 4. Lego LPF2 Emulation (viele China-Clones nutzen das)
    {'name': 'LPF2 Port A (Lego)', 'cmd': '08 00 81 00 11 51 00 64', 'stop': '08 00 81 00 11 51 00 00', 'hex': true},

    // 5. "AB CD" PROTOKOLL ---
    {'name': 'ABCD Port A Vollgas', 'cmd': 'AB CD 01 64 00 00 00 64', 'stop': 'AB CD 01 00 00 00 00 00', 'hex': true},
    {'name': 'ABCD Port D 30%', 'cmd': 'AB CD 01 00 00 00 1E 1E', 'stop': 'AB CD 01 00 00 00 00 00', 'hex': true},
    {'name': 'ABCD Port A Rückwärts', 'cmd': 'AB CD 01 9C 00 00 00 9C', 'stop': 'AB CD 01 00 00 00 00 00', 'hex': true},
  
    // 6. Die Klassiker (nur zur Sicherheit)
    {'name': 'Qiqiazi Port A', 'cmd': '5A 6B 02 00 05 01 64 08 64 01', 'stop': '5A 6B 02 00 05 01 00 08 00 01', 'hex': true},
    {'name': 'Vara 5B', 'cmd': 'CC 01 64 00 00', 'stop': 'CC 01 00 00 00', 'hex': true},
  
  ];

  @override
  void initState() {
    super.initState();
    _log("Labor bereit. Bitte Scan manuell starten.");
  }

  @override
  void dispose() {
    _driveTimer?.cancel();
    _device?.disconnect();
    _scrollController.dispose();
    super.dispose();
  }

  String _safeId(String uuid) {
    String s = uuid.toUpperCase();
    if (s.length < 8) return s;
    return s.contains("-") ? s.substring(4, 8) : s.substring(0, 4);
  }

  void _log(String msg) {
    if (!mounted) return;
    setState(() => _consoleLogs.add("[${DateTime.now().toString().substring(11, 19)}] $msg"));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _safeStartScan() async {
    if (_isScanning) return;
    _log("Prüfe Bluetooth...");
    try {
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) { _log("⚠️ Bluetooth AUS!"); return; }
      setState(() { _isScanning = true; _isConnected = false; _foundConfigs.clear(); });
      _log("Scan läuft...");
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    } catch (e) { _log("❌ Scan-Fehler: $e"); }
    setState(() => _isScanning = false);
  }

  Future<void> _connect(BluetoothDevice d) async {
    _log("Verbinde...");
    try {
      await FlutterBluePlus.stopScan();
      await d.connect(timeout: const Duration(seconds: 5));
      _device = d;
      _log("Analysiere Services...");
      List<BluetoothService> svcs = await d.discoverServices();
      List<BluetoothCharacteristic> writeChars = [];
      for (var s in svcs) {
        for (var c in s.characteristics) {
          if (c.properties.write || c.properties.writeWithoutResponse) writeChars.add(c);
        }
      }
      setState(() { _writeableChars = writeChars; _isConnected = true; });
      _log("✅ Verbunden. ${writeChars.length} Kanäle.");
    } catch (e) { _log("❌ Fehler."); }
  }

  Future<void> _runMatrixScan() async {
    if (_isAutoProbing) return;
    setState(() { _isAutoProbing = true; _foundConfigs.clear(); _testHistory.clear(); });
    _log("🚀 MATRIX-SCAN...");

    for (var char in _writeableChars) {
      String cId = _safeId(char.uuid.toString());
      for (var proto in _protocols) {
        for (bool ack in [true, false]) {
          if (!_isAutoProbing) return;
          _log("👉 $cId: ${proto['name']} (ACK: $ack)");
          try {
            bool ok = await _sendInternal(char, proto['cmd'], proto['hex'], ack);
            if (ok) {
              _log("✨ OK!");
              setState(() => _foundConfigs.add(FoundConfig(
                name: "${proto['name']} ($cId, ACK: $ack)",
                char: char, cmd: proto['cmd'], stopCmd: proto['stop'], isHex: proto['hex'], useAck: ack
              )));
            }
          } catch (e) {}
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    }
    _log("🏁 Scan fertig.");
    setState(() => _isAutoProbing = false);
  }

  void _startAutoTestSequence() {
    if (_foundConfigs.isEmpty) return;
    setState(() { _isAutoTesting = true; _currentTestIndex = 0; });
    _runNextTest();
  }

  void _runNextTest() async {
    if (_currentTestIndex >= _foundConfigs.length) {
      setState(() => _isAutoTesting = false);
      _log("🏁 Ende der Testreihe.");
      return;
    }
    final cfg = _foundConfigs[_currentTestIndex];
    _log("🚗 Test ${_currentTestIndex + 1}/${_foundConfigs.length}...");
    
    int count = 0;
    _driveTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) async {
      await _sendInternal(cfg.char, cfg.cmd, cfg.isHex, cfg.useAck);
      count++;
      if (count >= 10) { 
        timer.cancel();
        await _sendInternal(cfg.char, cfg.stopCmd, cfg.isHex, cfg.useAck);
        _log("⏹ Stopp.");
        _askUser(cfg);
      }
    });
  }

  void _askUser(FoundConfig cfg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Test ${_currentTestIndex + 1}/${_foundConfigs.length}"),
        content: Text("Hat sich der Hub bewegt?\n(${cfg.name})"),
        actions: [
          TextButton(onPressed: () { _saveAndNext(cfg, false, ctx); }, child: const Text("NEIN ❌", style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () { _saveAndNext(cfg, true, ctx); }, child: const Text("JA ✅", style: TextStyle(color: Colors.green))),
        ],
      ),
    );
  }

  void _saveAndNext(FoundConfig cfg, bool success, BuildContext dCtx) {
    setState(() { _testHistory.add(TestResult(cfg.name, success)); _currentTestIndex++; });
    Navigator.pop(dCtx);
    _runNextTest();
  }

  Future<bool> _sendInternal(BluetoothCharacteristic c, String cmd, bool hex, bool ack) async {
    try {
      List<int> bytes = hex ? _hexToBytes(cmd) : utf8.encode(cmd);
      await c.write(bytes, withoutResponse: !ack);
      return true;
    } catch (e) { return false; }
  }

  List<int> _hexToBytes(String hex) {
    String clean = hex.replaceAll(' ', '');
    List<int> b = [];
    for (int i = 0; i < clean.length; i += 2) b.add(int.parse(clean.substring(i, i + 2), radix: 16));
    if (b.length == 10) { 
      int sum = 0; for (var byte in b) sum += byte;
      b.add(sum & 0xFF);
    }
    return b;
  }

  void _export() {
    String data = jsonEncode(_testHistory.map((h) => h.toJson()).toList());
    Clipboard.setData(ClipboardData(text: data));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ergebnisse kopiert!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Noppen-Labor v8"),
        actions: [
          if (_testHistory.isNotEmpty) 
            TextButton.icon(onPressed: _export, icon: const Icon(Icons.copy_all, color: Colors.white), label: const Text("Ergebnisse exportieren", style: TextStyle(color: Colors.white, fontSize: 11)))
        ],
      ),
      body: Column(
        children: [
          if (!_isConnected) _buildScanner() else _buildLab(),
          _buildTerminal(),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _safeStartScan,
              icon: Icon(_isScanning ? Icons.sync : Icons.bluetooth_searching),
              label: Text(_isScanning ? "SUCHE LÄUFT..." : "SCAN STARTEN"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: FlutterBluePlus.scanResults,
              builder: (c, s) {
                var list = (s.data ?? []).where((r) => r.rssi > -95).toList();
                list.sort((a, b) => b.rssi.compareTo(a.rssi));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final r = list[i];
                    Color sig = r.rssi > -70 ? Colors.green : (r.rssi > -85 ? Colors.orange : Colors.red);
                    return ListTile(
                      leading: Icon(Icons.bluetooth, color: sig),
                      title: Text(r.device.platformName.isEmpty ? "Hub" : r.device.platformName),
                      trailing: Text("${r.rssi} dBm", style: TextStyle(color: sig, fontWeight: FontWeight.bold)),
                      onTap: () => _connect(r.device),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLab() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isAutoProbing || _isAutoTesting ? null : _runMatrixScan,
              child: Text(_isAutoProbing ? "SUCHE LÄUFT..." : "1. MATRIX-SCAN"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
            if (_foundConfigs.isNotEmpty) ...[
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _isAutoTesting ? null : _startAutoTestSequence,
                child: Text(_isAutoTesting ? "TESTREIHE LÄUFT..." : "2. AUTO-FAHRTEST STARTEN"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ],
            if (_isAutoTesting) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(value: (_currentTestIndex) / _foundConfigs.length),
            ),
            const Divider(height: 40),
            ..._testHistory.map((h) => ListTile(dense: true, title: Text(h.configName), trailing: Icon(h.success ? Icons.check : Icons.close, color: h.success ? Colors.green : Colors.red))).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminal() {
    return Container(
      height: 180, width: double.infinity, color: Colors.black,
      child: ListView.builder(
        controller: _scrollController, itemCount: _consoleLogs.length,
        itemBuilder: (c, i) => Text(_consoleLogs[i], style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace')),
      ),
    );
  }
}