import 'package:flutter/material.dart';
import '../settings_manager.dart';
import '../localization.dart';
import '../controllers/handset_manager.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _currentScale = 1.0;
  int _currentTheme = 0; 
  bool _wakelock = false;
  String _currentLang = 'de';

  bool _isHandsetScanning = false;
  bool _isHandsetConnected = false;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
    _isHandsetConnected = HandsetManager.instance.isConnected;
  }

  void _loadAllSettings() async {
    final scale = await SettingsManager.loadScale();
    final theme = await SettingsManager.loadTheme();
    final wake = await SettingsManager.loadWakelock();
    final lang = await SettingsManager.loadLanguage();
    
    setState(() {
      _currentScale = scale;
      _currentTheme = theme;
      _wakelock = wake;
      _currentLang = lang;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rundum-Schutz für das Kameraloch
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text('settings_title'.tr),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- SPRACHE ---
            Card(
              child: ListTile(
                leading: const Icon(Icons.language, color: Colors.blueGrey),
                title: const Text("Sprache / Language", style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: DropdownButton<String>(
                  value: _currentLang,
                  underline: const SizedBox(),
                  onChanged: (String? newValue) async {
                    if (newValue != null) {
                      await SettingsManager.saveLanguage(newValue);
                      L10n.lang = newValue; 
                      setState(() => _currentLang = newValue);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('lang_changed'.tr)),
                      );
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'de', child: Text("Deutsch")),
                    DropdownMenuItem(value: 'en', child: Text("English")),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- LEGO FERNBEDIENUNG ---
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.gamepad, 
                  color: _isHandsetConnected ? Colors.green : Colors.blueGrey,
                  size: 32,
                ),
                // "LEGO Handset (88010)" können wir als Eigenname hart codiert lassen, 
                // oder du packst es auch ins Dictionary.
                title: const Text("LEGO Handset (88010)", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_isHandsetConnected
                    ? 'handset_connected'.tr // NEU
                    : (_isHandsetScanning ? 'handset_scanning'.tr : 'handset_disconnected'.tr)), // NEU
                trailing: _isHandsetScanning
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(strokeWidth: 2)
                      )
                    : ElevatedButton(
                        onPressed: _isHandsetConnected ? _disconnectHandset : _startHandsetScan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isHandsetConnected ? Colors.red.shade50 : Colors.greenAccent.shade100,
                          foregroundColor: _isHandsetConnected ? Colors.red : Colors.green.shade900,
                          elevation: 0,
                        ),
                        child: Text(_isHandsetConnected ? 'btn_disconnect'.tr : 'btn_connect'.tr), // NEU
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // --- SKALIERUNG ---
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.format_size),
                    title: Text('ui_scaling'.tr),
                    subtitle: Text("${(_currentScale * 100).toInt()}%"),
                  ),
                  Slider(
                    value: _currentScale,
                    min: 0.5,
                    max: 1.5,
                    divisions: 10,
                    onChanged: (val) {
                      setState(() => _currentScale = val);
                      SettingsManager.saveScale(val);
                    },
                  ),
                ],
              ),
            ),
            
            // --- WAKELOCK ---
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.lightbulb_outline),
                title: Text('display_always_on'.tr),
                subtitle: Text('display_always_on_desc'.tr, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor,),),
                value: _wakelock,
                onChanged: (val) {
                  setState(() => _wakelock = val);
                  SettingsManager.saveWakelock(val);
                  SettingsManager.setWakelock(val);
                },
              ),
            ),

            // --- DESIGN / THEME ---
            Card(
              child: ListTile(
                leading: const Icon(Icons.brightness_6),
                title: Text('design_theme'.tr),
                trailing: DropdownButton<int>(
                  value: _currentTheme,
                  underline: const SizedBox(),
                  onChanged: (val) {
                    setState(() => _currentTheme = val!);
                    SettingsManager.saveTheme(val!);
                  },
                  items: [
                    DropdownMenuItem(value: 0, child: Text('theme_system'.tr)),
                    DropdownMenuItem(value: 1, child: Text('theme_light'.tr)),
                    DropdownMenuItem(value: 2, child: Text('theme_dark'.tr)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// ==========================================
  // HANDSET BLUETOOTH LOGIK
  // ==========================================

  void _startHandsetScan() async {
    setState(() => _isHandsetScanning = true);

    try {
      await FlutterBluePlus.stopScan();

      var subscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          // LEGO Geräte (Manufacturer Data 919) 
          if (r.advertisementData.manufacturerData.containsKey(919)) {
            List<int> data = r.advertisementData.manufacturerData[919]!;
            
            // Ist es das Handset (System-ID 0x42)?
            if (data.length >= 2 && data[1] == 0x42) {
              FlutterBluePlus.stopScan();
              await _connectToHandset(r.device);
              break; 
            }
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      
      await Future.delayed(const Duration(seconds: 15));
      if (mounted && _isHandsetScanning) {
         setState(() => _isHandsetScanning = false);
         subscription.cancel();
      }
    } catch (e) {
      debugPrint("Fehler beim Handset-Scan: $e");
      if (mounted) setState(() => _isHandsetScanning = false);
    }
  }

  Future<void> _connectToHandset(BluetoothDevice device) async {
    try {
      await device.connect();
      // Dem Singleton das Device übergeben
      await HandsetManager.instance.connect(device);
      
      if (mounted) {
        setState(() {
          _isHandsetConnected = true;
          _isHandsetScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('handset_paired_success'.tr), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Fehler bei der Verbindung: $e");
      if (mounted) setState(() => _isHandsetScanning = false);
    }
  }

  void _disconnectHandset() async {
    await HandsetManager.instance.disconnect();
    if (mounted) {
      setState(() {
        _isHandsetConnected = false;
      });
    }
  }

}