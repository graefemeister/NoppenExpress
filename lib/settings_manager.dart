import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SettingsManager {
  static const String _keyScale = 'ui_scale';
  static const String _keyTheme = 'app_theme';
  static const String _keyWakelock = 'app_wakelock';
  static const String _keyLang = 'app_lang';

  // --- SKALIERUNG ---
  static Future<void> saveScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyScale, scale);
  }

  static Future<double> loadScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyScale) ?? 1.0;
  }

  // --- THEME (0=System, 1=Light, 2=Dark) ---
  static Future<void> saveTheme(int theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTheme, theme);
  }

  static Future<int> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTheme) ?? 0;
  }

  // --- WAKELOCK (Bildschirm anlassen) ---
  // Das hier speichert den Zustand (für den Switch in den Settings)
  static Future<void> saveWakelock(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWakelock, enabled);
  }

  static Future<bool> loadWakelock() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWakelock) ?? true;
  }

  // Das hier führt die Aktion wirklich aus
  static Future<void> setWakelock(bool enabled) async {
    await WakelockPlus.toggle(enable: enabled);
  }

  // --- SPRACHE ---
  static Future<void> saveLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLang, lang);
  }

  static Future<String> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLang) ?? 'de';
  }
}