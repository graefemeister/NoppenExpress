import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'train_core.dart'; 
import 'train_manager.dart';
import 'workshop_screen.dart'; 
import 'settings_manager.dart';
import 'settings_screen.dart';
import 'readme_screen.dart';
import 'localization.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized(); 
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  L10n.lang = await SettingsManager.loadLanguage();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

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

class DashboardScreen extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  const DashboardScreen({super.key, required this.onSettingsChanged});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _permissionsGranted = false;
  bool _isLoading = true; 
  List<TrainController> _lokListe = []; 
  TrainController? _selectedTrain; 

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _requestPermissions();
    await _loadTrains();
  }

  // --- DIE HÖRSTATION FÜR STATUS-ÄNDERUNGEN (INKL. SNACKBAR) ---
  void _attachTrainListener(TrainController train) {
    train.onStatusChanged = () {
      if (mounted) {
        setState(() {}); // Sortiert die Liste neu

        if (!train.isRunning) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.link_off, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text("Verbindung zu '${train.name}' verloren!", style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    };
  }

  Future<void> _loadTrains() async {
    setState(() => _isLoading = true);
    final loaded = await TrainManager.loadTrains();
    for (var train in loaded) {
      _attachTrainListener(train);
    }
    setState(() {
      _lokListe = loaded;
      _isLoading = false;
    });
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    }
    setState(() { _permissionsGranted = true; });
  }

  void _globalEmergencyStop() {
    int stoppedCount = 0;
    for (var train in _lokListe) {
      if (train.isRunning) {
        train.emergencyStop();
        stoppedCount++;
      }
    }
    setState(() {}); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.warning, color: Colors.white), const SizedBox(width: 12), 
        Text("${'global_stop'.tr}: $stoppedCount")]),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: "NoppenExpress",
      applicationVersion: "Version 1.8.6",
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/applogo.png',
          width: 60, height: 60,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.train, size: 60), 
        ),
      ),
      applicationLegalese: "© 2026 graefemeister@gmail.com",
      children: [
        const SizedBox(height: 16),
        const Text("NoppenExpress - Hobbyprojekt für Klemmbausteinfreunde"),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            final Uri url = Uri.parse('https://github.com/graefemeister'); 
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) debugPrint('Fehler');
          },
          icon: const Icon(Icons.code),
          label: const Text("Projekt auf GitHub unterstützen"),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF24292E), foregroundColor: Colors.white),
        ),
      ],
    );
  }

  void _openWorkshop({TrainController? trainToEdit}) async {
    final TrainController? result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => WorkshopScreen(existingTrains: _lokListe, trainToEdit: trainToEdit))
    );

    if (result != null) {
      _attachTrainListener(result);
      setState(() {
        if (trainToEdit != null) {
          trainToEdit.disconnect(); 
          int index = _lokListe.indexOf(trainToEdit);
          _lokListe[index] = result;
          if (_selectedTrain == trainToEdit) _selectedTrain = result;
        } else {
          _lokListe.add(result);
        }
      });
      await TrainManager.saveTrains(_lokListe);
    }
  }

  void _exportData() async {
    try {
      String jsonData = await TrainManager.exportAsJson();
      if (jsonData == "[]" || jsonData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Keine Loks zum Exportieren vorhanden.")));
        return;
      }
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/NoppenExpress_Backup.json';
      final file = File(filePath);
      await file.writeAsString(jsonData);
      await Share.shareXFiles([XFile(file.path)], subject: 'NoppenExpress Lok-Backup', text: 'Hier ist dein NoppenExpress Backup!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export fehlgeschlagen: $e")));
    }
  }

  void _importData() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      List<TrainController> imported = TrainManager.loadTrainsFromContent(content);
      for (var t in imported) { _attachTrainListener(t); }
      if (imported.isNotEmpty) {
        setState(() => _lokListe.addAll(imported));
        await TrainManager.saveTrains(_lokListe);
      }
    }
  }

  void _deleteTrain(TrainController train) async {
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('confirm_delete'.tr), 
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('cancel'.tr)), 
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('delete'.tr, style: const TextStyle(color: Colors.red)))
      ]));
    if (confirm == true) {
      setState(() { _lokListe.remove(train); if (_selectedTrain == train) _selectedTrain = null; });
      await TrainManager.saveTrains(_lokListe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedList = List<TrainController>.from(_lokListe)..sort((a, b) {
      if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text("NoppenExpress", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.cyanAccent.withOpacity(0.15) 
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent.withOpacity(0.5) : Colors.blue.withOpacity(0.5)),
              ),
              child: Text('BLE', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.blue.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0), child: ElevatedButton.icon(onPressed: _globalEmergencyStop, icon: const Icon(Icons.bolt, color: Colors.white), label: Text('global_stop'.tr), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white))),
          IconButton(icon: const Icon(Icons.add_box_outlined), onPressed: () => _openWorkshop(), tooltip: 'new_train'.tr),
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'export') _exportData();
              if (val == 'import') _importData();
              if (val == 'settings') { await Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsScreen())); widget.onSettingsChanged(); }
              if (val == 'readme') Navigator.push(context, MaterialPageRoute(builder: (c) => const ReadmeScreen()));
              if (val == 'about') _showAbout();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'export', child: Row(children: [const Icon(Icons.upload, size: 20), const SizedBox(width: 8), Text('export'.tr)])),
              PopupMenuItem(value: 'import', child: Row(children: [const Icon(Icons.download, size: 20), const SizedBox(width: 8), Text('import'.tr)])),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'settings', child: Row(children: [const Icon(Icons.settings, size: 20), const SizedBox(width: 8), Text('settings'.tr)])),
              PopupMenuItem(value: 'readme', child: Row(children: [const Icon(Icons.menu_book, size: 20), const SizedBox(width: 8), Text('readme'.tr)])),
              PopupMenuItem(value: 'about', child: Row(children: [const Icon(Icons.info_outline, size: 20), const SizedBox(width: 8), Text('about'.tr)])),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !_permissionsGranted 
          ? const Center(child: Text("Berechtigungen fehlen"))
          : _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : Row(
                  children: [
                    Container(
                      width: 300,
                      color: Theme.of(context).cardColor,
                      child: sortedList.isEmpty 
                        ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('no_trains'.tr, textAlign: TextAlign.center)))
                        : ListView.separated(
                            itemCount: sortedList.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final train = sortedList[index];
                              return ListTile(
                                leading: ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 70, height: 44, child: train.imagePath.isEmpty ? Container(color: Colors.grey.shade200, child: const Icon(Icons.train)) : (train.imagePath.startsWith('assets/') ? Image.asset(train.imagePath, fit: BoxFit.cover) : Image.file(File(train.imagePath), fit: BoxFit.cover)))),
                                title: Text(train.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: train.isRunning ? Colors.green : Colors.red, shape: BoxShape.circle)), const SizedBox(width: 4), Text(train.isRunning ? 'online'.tr : 'offline'.tr, style: const TextStyle(fontSize: 10))]),
                                selected: _selectedTrain == train,
                                onTap: () => setState(() => _selectedTrain = train),
                                onLongPress: () {
                                   showModalBottomSheet(
                                    context: context,
                                    builder: (ctx) => Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(leading: const Icon(Icons.edit), title: Text('edit'.tr), onTap: () { Navigator.pop(ctx); _openWorkshop(trainToEdit: train); }),
                                        ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: Text('delete'.tr, style: const TextStyle(color: Colors.red)), onTap: () { Navigator.pop(ctx); _deleteTrain(train); }),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _selectedTrain == null
                          ? Center(child: Text('select_train'.tr))
                          : TrainControlPanel(key: ValueKey(_selectedTrain!.config.id), train: _selectedTrain!, onStateChanged: () => setState(() {})),
                    ),
                  ],
                ),
    );
  }
}

class TrainControlPanel extends StatefulWidget {
  final TrainController train;
  final VoidCallback onStateChanged; 
  const TrainControlPanel({super.key, required this.train, required this.onStateChanged});
  @override
  State<TrainControlPanel> createState() => _TrainControlPanelState();
}

class _TrainControlPanelState extends State<TrainControlPanel> {
  bool _isConnecting = false;
  String _currentGearText = "0";

  Future<void> _toggleConnection() async {
    if (widget.train.isRunning) {
      widget.train.emergencyStop();
      await Future.delayed(const Duration(milliseconds: 300));
      await widget.train.disconnect();
      setState(() => _currentGearText = "0");
    } else {
      setState(() => _isConnecting = true);
      try { await widget.train.connectAndInitialize(); } catch (e) { debugPrint("Fehler"); }
    }
    if (mounted) { setState(() => _isConnecting = false); widget.onStateChanged(); }
  }

  void _setGear(int gear, bool forward, String label) {
    if (!widget.train.isRunning) return;
    widget.train.setGear(gear, forward: forward);
    setState(() => _currentGearText = gear == 0 ? "0" : label);
  }

  Widget _buildGearButton(String label, int gear, bool forward) {
    bool isActive = _currentGearText == label; 
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: () => _setGear(gear, forward, label),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            backgroundColor: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor.withOpacity(0.85),
            foregroundColor: isActive ? Colors.black : Theme.of(context).textTheme.bodyLarge?.color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: isActive ? 6 : 1,
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = widget.train.isRunning;
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.6,
            child: widget.train.imagePath.isEmpty
                ? const Icon(Icons.train, size: 200)
                : (widget.train.imagePath.startsWith('assets/')
                    ? Image.asset(widget.train.imagePath, fit: BoxFit.cover)
                    : Image.file(File(widget.train.imagePath), fit: BoxFit.cover)),
          ),
        ),
        Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Theme.of(context).scaffoldBackgroundColor.withOpacity(0.1), Theme.of(context).scaffoldBackgroundColor], stops: const [0.4, 0.9])))),
        SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.train.name, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)), Text(() { switch (widget.train.config.protocol) { case 'mould_king': return 'Mould King (Modern)'; case 'lego_hub': return 'LEGO Powered Up'; case 'circuit_cube': return 'Circuit Cube'; default: return 'Unbekanntes Protokoll'; } }(), style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary.withOpacity(0.8), fontWeight: FontWeight.w500))])),
                  SizedBox(height: 60, width: 220, child: ElevatedButton.icon(onPressed: _isConnecting ? null : _toggleConnection, icon: Icon(isConnected ? Icons.link_off : Icons.link), label: Text(isConnected ? 'disconnect'.tr : 'connect'.tr, style: const TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: isConnected ? Colors.red.shade700 : Colors.green.shade700, foregroundColor: Colors.white))),
                ],
              ),
              const SizedBox(height: 40),
              Row(children: [_buildGearButton("V1", 1, true), _buildGearButton("V2", 2, true), _buildGearButton("V3", 3, true), _buildGearButton("V4", 4, true)]),
              const SizedBox(height: 12),
              Row(children: [_buildGearButton("R1", 1, false), _buildGearButton("R2", 2, false), _buildGearButton("R3", 3, false), _buildGearButton("R4", 4, false)]),
              const SizedBox(height: 24),
              Row(children: [Expanded(child: ElevatedButton.icon(onPressed: () => _setGear(0, true, "0"), icon: const Icon(Icons.pause_circle_filled, size: 28), label: Text('halt'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: Colors.orange.shade400, foregroundColor: Colors.white))), const SizedBox(width: 16), Expanded(child: ElevatedButton.icon(onPressed: () { widget.train.emergencyStop(); setState(() { _currentGearText = "0"; }); }, icon: const Icon(Icons.warning_amber_rounded, size: 28), label: Text('stop'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: Colors.red.shade800, foregroundColor: Colors.white)))]),
              if (widget.train.config.notes.isNotEmpty) ...[const SizedBox(height: 32), Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.amber.withOpacity(0.15) : Colors.amber.shade50.withOpacity(0.9), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.description_outlined, size: 16, color: Colors.orange), const SizedBox(width: 8), Text('notes_header'.tr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange))]), const SizedBox(height: 8), Text(widget.train.config.notes, style: const TextStyle(fontSize: 16, height: 1.5))]))],
              const SizedBox(height: 32), const Divider(), const SizedBox(height: 16),
              Row(children: [Text('accessories'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(width: 16), FilterChip(label: Text('light_b'.tr), selected: widget.train.lightB > 0, onSelected: (val) { widget.train.setLight('B', val); setState(() {}); }), const SizedBox(width: 8), FilterChip(label: Text('light_c'.tr), selected: widget.train.lightC > 0, onSelected: (val) { widget.train.setLight('C', val); setState(() {}); }), const Spacer(), ActionChip(avatar: const Icon(Icons.swap_horiz, size: 18), label: Text('invert'.tr), backgroundColor: widget.train.inverted ? Colors.orange.withOpacity(0.4) : null, onPressed: () { widget.train.toggleInverted(); setState(() {}); })]),
            ],
          ),
        ),
      ],
    );
  }
}