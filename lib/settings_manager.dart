import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SettingsManager {
  static const String _keyScale = 'ui_scale';
  static const String _keyAutoScale = 'ui_auto_scale'; // NEU
  static const String _keyTheme = 'app_theme';
  static const String _keyWakelock = 'app_wakelock';
  static const String _keyLang = 'app_lang';
  static const String _keyBgMode = 'background_mode';

  // --- SKALIERUNG ---
  static Future<void> saveScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyScale, scale);
  }

  static Future<double> loadScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyScale) ?? 1.0;
  }

  // --- AUTO-SKALIERUNG ---
  static Future<void> saveAutoScale(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoScale, enabled);
  }

  static Future<bool> loadAutoScale() async {
    final prefs = await SharedPreferences.getInstance();
    // WICHTIG: Standardwert ist hier 'true', damit es bei neuen Nutzern direkt aktiv ist!
    return prefs.getBool(_keyAutoScale) ?? true; 
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
  static Future<void> saveWakelock(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWakelock, enabled);
  }

  static Future<bool> loadWakelock() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWakelock) ?? true;
  }

  static Future<void> setWakelock(bool enabled) async {
    await WakelockPlus.toggle(enable: enabled);
  }

  // --- HINTERGRUND-SERVICE (Hosentaschen-Modus) ---
  static Future<void> saveBackgroundMode(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBgMode, isEnabled);
  }

  static Future<bool> loadBackgroundMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBgMode) ?? false;
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