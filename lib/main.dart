// Copyright (c) 2026 [graefemeister]
// This software is released under the GNU General Public License v3.0.
// https://www.gnu.org/licenses/gpl-3.0.html

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'settings_manager.dart';
import 'localization.dart';
import 'screens/dashboard_screen.dart';
import 'services/background_service.dart'; 

void main() async {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['NoppenExpress'],
      'GNU General Public License v3.0\n\nCopyright (C) 2026 [graefemeister]...',
    );
  });
  
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized(); 
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  L10n.lang = await SettingsManager.loadLanguage();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  BackgroundService.init();

  runApp(const NoppenExpressApp());

  await Future.delayed(const Duration(seconds: 3));
  FlutterNativeSplash.remove();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

class NoppenExpressApp extends StatefulWidget {
  const NoppenExpressApp({super.key});
  @override
  State<NoppenExpressApp> createState() => _NoppenExpressAppState();
}

class _NoppenExpressAppState extends State<NoppenExpressApp> {
  ThemeMode _themeMode = ThemeMode.system;
  double _uiScale = 1.0;

  @override
  void initState() {
    super.initState();
    _refreshSettings();
  }

  void _refreshSettings() async {
    final themeInt = await SettingsManager.loadTheme();
    final scaleDouble = await SettingsManager.loadScale();
    final wakelockBool = await SettingsManager.loadWakelock();
    final savedLang = await SettingsManager.loadLanguage();
    
    await SettingsManager.setWakelock(wakelockBool);

    setState(() {
      L10n.lang = savedLang;
      if (themeInt == 1) {
        _themeMode = ThemeMode.light;
      } else if (themeInt == 2) {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      _uiScale = scaleDouble;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoppenExpress', 
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B0FF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.grey.shade50,
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7BCBEB), 
          brightness: Brightness.dark,
          surface: Colors.black,             
          primary: const Color(0xFF00E5FF),  
        ),
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF121212),  
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_uiScale),
          ),
          child: child!,
        );
      },
      home: DashboardScreen(onSettingsChanged: _refreshSettings),
    );
  }
}