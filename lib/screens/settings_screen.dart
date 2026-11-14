import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/l10n_extension.dart';
import '../settings_manager.dart';
import '../controllers/handset_manager.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/background_service.dart'; 

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onSettingsChanged;

  const SettingsScreen({
    super.key,
    this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _currentScale = 1.0;
  bool _isAutoScale = true;
  int _currentTheme = 0; 
  bool _wakelock = false;
  bool _isBackgroundModeEnabled = false;
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
    final bgMode = await SettingsManager.loadBackgroundMode();
    
    setState(() {
      _currentScale = scale;
      _currentTheme = theme;
      _wakelock = wake;
      _isBackgroundModeEnabled = bgMode;
      _currentLang = (lang == null || lang.isEmpty) ? 'system' : lang;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.settings),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- SPRACHE ---
            Card(
              child: ListTile(
                leading: Icon(Icons.language, color: Theme.of(context).colorScheme.primary),
                title: const Text("Sprache / Language", style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: DropdownButton<String>(
                  value: _currentLang,
                  underline: const SizedBox(),
                  onChanged: (String? newValue) async {
                    if (newValue != null) {
                      await SettingsManager.saveLanguage(newValue);
                      
                      setState(() => _currentLang = newValue);
                      
                      widget.onSettingsChanged?.call();

                      Future.delayed(const Duration(milliseconds: 50), () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.lang_changed)),
                          ); 
                        });
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'system', child: Text("System (Auto)")), // NEU
                    DropdownMenuItem(value: 'de', child: Text("Deutsch")),
                    DropdownMenuItem(value: 'en', child: Text("English")),
                    DropdownMenuItem(value: 'fr', child: Text("Français")),
                    DropdownMenuItem(value: 'it', child: Text("Italiano")),
                    DropdownMenuItem(value: 'da', child: Text("Dansk")),
                    DropdownMenuItem(value: 'nl', child: Text("Nederlands")),
                    DropdownMenuItem(value: 'pl', child: Text("Polski")),
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
                  color: _isHandsetConnected ? Colors.green : Theme.of(context).colorScheme.primary, // Nur verbunden ist grün
                  size: 32,
                ),
                title: const Text("LEGO Handset (88010)", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_isHandsetConnected
                    ? context.l10n.handset_connected
                    : (_isHandsetScanning ? context.l10n.handset_scanning : context.l10n.handset_disconnected)),
                trailing: _isHandsetScanning
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(strokeWidth: 2)
                      )
                    : OutlinedButton( 
                        onPressed: _isHandsetConnected ? _disconnectHandset : _startHandsetScan,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isHandsetConnected ? Colors.red : Theme.of(context).colorScheme.primary,
                          side: BorderSide(
                            color: _isHandsetConnected ? Colors.red.withOpacity(0.5) : Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          ),
                        ),
                        child: Text(_isHandsetConnected ? context.l10n.btn_disconnect : context.l10n.btn_connect),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // --- SKALIERUNG ---
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(Icons.autorenew, color: Theme.of(context).colorScheme.primary),
                    title: Text(context.l10n.ui_auto_scale, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      context.l10n.ui_auto_scale_desc,
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _isAutoScale,
                    activeColor: Theme.of(context).colorScheme.primary, 
                    onChanged: (val) async {
                      setState(() => _isAutoScale = val);
                      await SettingsManager.saveAutoScale(val); 
                      
                      if (val) {
                        setState(() => _currentScale = 1.0);
                        await SettingsManager.saveScale(1.0);

                        if (widget.onSettingsChanged != null) {
                            widget.onSettingsChanged!();
                        }
                      }
                    },
                  ),
                  
                  const Divider(height: 1, indent: 16, endIndent: 16),

                  ListTile(
                    leading: Icon(Icons.format_size, color: _isAutoScale ? Colors.grey : Theme.of(context).colorScheme.primary),
                    title: Text(
                      context.l10n.ui_scaling_manual, 
                      style: TextStyle(color: _isAutoScale ? Colors.grey : null)
                    ),
                    subtitle: Text(
                      _isAutoScale ? "Auto" : "${(_currentScale * 100).toInt()}%",
                    ),
                  ),
                  Opacity(
                    opacity: _isAutoScale ? 0.3 : 1.0,
                    child: IgnorePointer(
                      ignoring: _isAutoScale,
                      child: Slider(
                        value: _currentScale,
                        min: 0.5,
                        max: 1.5,
                        divisions: 10,
                        activeColor: Theme.of(context).colorScheme.primary, // Einheitlich!
                        onChanged: (val) {
                          setState(() => _currentScale = val);
                          SettingsManager.saveScale(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // --- WAKELOCK ---
            Card(
              child: SwitchListTile(
                secondary: Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.primary),
                title: Text(context.l10n.display_always_on, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(context.l10n.display_always_on_desc, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor,),),
                value: _wakelock,
                activeColor: Theme.of(context).colorScheme.primary, // Einheitlich!
                onChanged: (val) {
                  setState(() => _wakelock = val);
                  SettingsManager.saveWakelock(val);
                  SettingsManager.setWakelock(val);
                },
              ),
            ),

            // --- HOSENTASCHEN-MODUS (Hintergrund) ---
            Card(
              child: SwitchListTile(
                secondary: Icon(Icons.phonelink_lock, color: Theme.of(context).colorScheme.primary), 
                title: Text(
                  context.l10n.settings_bg_mode, 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
                subtitle: Text( 
                  context.l10n.settings_bg_mode_desc,
                  style: TextStyle(
                    fontSize: 12, 
                    color: Theme.of(context).hintColor
                  ),
                ),
                value: _isBackgroundModeEnabled,
                activeColor: Theme.of(context).colorScheme.primary, // Einheitlich!
                onChanged: (val) async {
                  await _handleBackgroundModeChange(val);
                },
              ),
            ),

            // --- DESIGN / THEME ---
            Card(
              child: ListTile(
                leading: Icon(Icons.brightness_6, color: Theme.of(context).colorScheme.primary),
                title: Text(context.l10n.design_theme, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: DropdownButton<int>(
                  value: _currentTheme,
                  underline: const SizedBox(),
                  onChanged: (val) {
                    setState(() => _currentTheme = val!);
                    SettingsManager.saveTheme(val!);

                    if (widget.onSettingsChanged != null) {
                      widget.onSettingsChanged!();
                    }
                  },
                  items: [
                    DropdownMenuItem(value: 0, child: Text(context.l10n.theme_system)),
                    DropdownMenuItem(value: 1, child: Text(context.l10n.theme_light)),
                    DropdownMenuItem(value: 2, child: Text(context.l10n.theme_dark)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBackgroundModeChange(bool enabled) async {
  if (enabled) {
    // 1. Berechtigung für Benachrichtigungen prüfen (Ab Android 13 Pflicht)
    if (Platform.isAndroid) {
      final NotificationPermission notificationPermission = 
          await FlutterForegroundTask.checkNotificationPermission();
      
      if (notificationPermission != NotificationPermission.granted) {
        // Dialog anfordern
        await FlutterForegroundTask.requestNotificationPermission();
      }
      
      // Falls der Nutzer immer noch abgelehnt hat: Abbruch
      if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
        if (mounted) {
          setState(() => _isBackgroundModeEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Berechtigung für Benachrichtigung erforderlich!")),
          );
        }
        return;
      }
    }

    // 2. Den Dienst wirklich starten
    bool success = await _startBackgroundService();
    if (success) {
      await SettingsManager.saveBackgroundMode(true);
      setState(() => _isBackgroundModeEnabled = true);
    }
  } else {
    // Dienst stoppen
    await _stopBackgroundService();
    await SettingsManager.saveBackgroundMode(false);
    setState(() => _isBackgroundModeEnabled = false);
  }
}

Future<bool> _startBackgroundService() async {
    // In v6.x prüfen wir so, ob der Dienst schon läuft
    if (await FlutterForegroundTask.isRunningService) {
      // Wir stoppen ihn kurz, um ihn mit frischen Daten neu zu starten
      await FlutterForegroundTask.stopService();
    }

    // FAKT: In v6.5.0 gibt startService direkt einen bool zurück.
    // Wir brauchen keine 'ServiceRequestResult' Klasse mehr.
    final bool success = await FlutterForegroundTask.startService(
      notificationTitle: context.l10n.settings_bg_mode,
      notificationText: context.l10n.settings_bg_mode_desc,
      callback: startCallback,
    );
    
    return success;
  }

Future<void> _stopBackgroundService() async {
  await FlutterForegroundTask.stopService();
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
          SnackBar(content: Text(context.l10n.handset_paired_success), backgroundColor: Colors.green),
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