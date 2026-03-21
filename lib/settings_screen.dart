import 'package:flutter/material.dart';
import 'settings_manager.dart';
import 'localization.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _currentScale = 1.0;
  int _currentTheme = 0; 
  bool _wakelock = true;
  String _currentLang = 'de';

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
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
}