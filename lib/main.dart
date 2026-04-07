// Copyright (c) 2026 [graefemeister]
// This software is released under the GNU General Public License v3.0.
// https://www.gnu.org/licenses/gpl-3.0.html


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Diese Zeile fehlt!
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
//import 'package:provider/provider.dart';


import 'controllers/controllers.dart'; 
import 'train_manager.dart';
import 'workshop_screen.dart'; 
import 'settings_manager.dart';
import 'settings_screen.dart';
import 'readme_screen.dart';
import 'localization.dart';
import 'diagnostic_screen.dart';

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

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  bool _permissionsGranted = false;
  bool _isLoading = true;
  List<TrainController> _lokListe = [];
  TrainController? _selectedTrain;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initApp();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    await _requestPermissions();
    await _loadTrains();
  }

  // --- DIE "VERMISSTEN" METHODEN ---

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [Permission.bluetoothScan, Permission.bluetoothAdvertise, Permission.bluetoothConnect, Permission.location].request();
    }
    setState(() { _permissionsGranted = true; });
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

  void _attachTrainListener(TrainController train) {
    train.onStatusChanged = () {
      if (mounted) {
        setState(() {});
        if (!train.isRunning) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${'connection_lost'.tr} '${train.name}'"),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    };
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
      SnackBar(content: Text("${'global_stop'.tr}: $stoppedCount"), backgroundColor: Colors.red.shade900),
    );
  }

  void _openWorkshop({TrainController? trainToEdit}) async {
    final TrainController? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WorkshopScreen(existingTrains: _lokListe, trainToEdit: trainToEdit)),
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
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/NoppenExpress_Backup.json');
      await file.writeAsString(jsonData);
      await Share.shareXFiles([XFile(file.path)], subject: 'NoppenExpress Backup');
    } catch (e) {
      debugPrint("Export Fehler: $e");
    }
  }

  void _importData() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      List<TrainController> imported = TrainManager.loadTrainsFromContent(content);
      for (var t in imported) { _attachTrainListener(t); }
      setState(() { _lokListe.addAll(imported); });
      await TrainManager.saveTrains(_lokListe);
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

  void _showTrainOptions(TrainController train) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit), title: Text('edit'.tr), onTap: () { Navigator.pop(ctx); _openWorkshop(trainToEdit: train); }),
            ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: Text('delete'.tr, style: const TextStyle(color: Colors.red)), onTap: () { Navigator.pop(ctx); _deleteTrain(train); }),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
  showAboutDialog(
    context: context,
    applicationName: "NoppenExpress",
    applicationVersion: "Version 1.9.6",
    applicationIcon: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/applogo.png',
        width: 60, height: 60,
        errorBuilder: (context, error, stackTrace) => 
          const Icon(Icons.train, size: 60, color: Colors.blueGrey), 
      ),
    ),
    applicationLegalese: "© 2026 graefemeister",
    children: [
      const SizedBox(height: 16),
      Text('about_description'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 10),
      Text(
        'about_credits_title'.tr,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6.0),
        child: Text(
          'about_credits_text'.tr,
          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () async {
          final Uri url = Uri.parse('https://github.com/graefemeister/NoppenExpress'); 
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            debugPrint('Fehler beim Öffnen von GitHub');
          }
        },
        icon: const Icon(Icons.code),
        label: Text('about_github_btn'.tr),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF444C56), 
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 45),
        ),
      ),
    ],
  );
}

  // --- DIE BUILD METHODE ---

  @override
  Widget build(BuildContext context) {
    final sortedList = List<TrainController>.from(_lokListe)..sort((a, b) {
      if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;

        Widget listPart = Container(
          color: Theme.of(context).cardColor,
          child: sortedList.isEmpty
              ? Center(child: Text('no_trains'.tr))
              : ListView.separated(
                  itemCount: sortedList.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final train = sortedList[i];
                    return ListTile(
                      // --- DAS VORSCHAU-BILD ---
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 50,
                          height: 32,
                          child: train.imagePath.isEmpty
                              ? Container(
                                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                                  child: const Icon(Icons.train, size: 20),
                                )
                              : (train.imagePath.startsWith('assets/')
                                  ? Image.asset(train.imagePath, fit: BoxFit.cover)
                                  : Image.file(File(train.imagePath), fit: BoxFit.cover)),
                        ),
                      ),
                      // --- TEXTE ---
                      title: Text(
                        train.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: train.isRunning ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(train.isRunning ? 'online'.tr : 'offline'.tr, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      selected: _selectedTrain == train,
                      onTap: () {
                        setState(() => _selectedTrain = train);
                        if (isPortrait) _tabController.animateTo(1);
                      },
                      onLongPress: () => _showTrainOptions(train),
                    );
                  },
                ),
        );

        Widget controlPart = _selectedTrain == null
            ? Center(child: Text('select_train'.tr))
            : TrainControlPanel(
                key: ValueKey(_selectedTrain!.config.id),
                train: _selectedTrain!,
                onStateChanged: () => setState(() {}),
              );

        return Scaffold(
          appBar: AppBar(
            title: const Text("NoppenExpress"),
            bottom: isPortrait
                ? TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(icon: const Icon(Icons.list), text: 'list'.tr),
                      Tab(icon: const Icon(Icons.settings_remote), text: 'controls'.tr),
                    ],
                  )
                : null,
            actions: [
                  TextButton.icon(onPressed: _globalEmergencyStop, 
                  icon: const Icon(Icons.bolt, color: Colors.red, size: 28), 
                  label: Text('stop_all'.tr, 
                  style: const TextStyle(
                    color: Colors.red, 
                    fontWeight: FontWeight.bold,
                    fontSize: 12
                  )
                ),
              ),
              IconButton(icon: const Icon(Icons.add_box_outlined), onPressed: () => _openWorkshop()),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'export') _exportData();
                  if (val == 'import') _importData();
                  if (val == 'about') _showAbout();
                  if (val == 'readme') Navigator.push(context, MaterialPageRoute(builder: (c) => const ReadmeScreen()));
                  if (val == 'settings') {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const SettingsScreen())).then((_) => widget.onSettingsChanged());
                  }
                  if (val == 'diagnosis') {Navigator.push(context, MaterialPageRoute(builder: (context) => const UniversalDiagnosticScreen(),),);}
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'export', child: Text('export'.tr)),
                  PopupMenuItem(value: 'import', child: Text('import'.tr)),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'readme', child: Row(children: [const Icon(Icons.menu_book, size: 20), const SizedBox(width: 8), Text('readme'.tr)])),
                  PopupMenuItem(value: 'settings', child: Row(children: [const Icon(Icons.settings, size: 20), const SizedBox(width: 8), Text('settings'.tr)])),
                  PopupMenuItem(value: 'about', child: Row(children: [const Icon(Icons.info_outline, size: 20), const SizedBox(width: 8), Text('about'.tr)])),                
                  PopupMenuItem(value: 'diagnosis', child: Row(children: [const Icon(Icons.build, size: 20), const SizedBox(width: 8), Text('diagnosis'.tr)])),
                  ],
              ),
            ],
          ),
          body: isPortrait
              ? TabBarView(controller: _tabController, children: [listPart, controlPart])
              : Row(children: [
                  Expanded(flex: 3, child: listPart),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 7, child: controlPart),
                ]),
        );
      },
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
      
      // Diese Zeile löst alle "config isn't defined" Fehler:
      final config = widget.train.config; 
      
      // Falls du die Blockade-Logik eingebaut hast, sollte sie hier folgen:
      if (widget.train.targetSpeed == 0 && _currentGearText != "0") {
        _currentGearText = "0";
      }

      final isLego = config.protocol == 'lego_hub';

    return Stack(
      children: [
        // --- HINTERGRUND-BILD ---
        Positioned.fill(
          child: Opacity(
            opacity: 0.6,
            child: config.imagePath.isEmpty
                ? const Icon(Icons.train, size: 200)
                : (config.imagePath.startsWith('assets/')
                    ? Image.asset(config.imagePath, fit: BoxFit.cover)
                    : Image.file(File(config.imagePath), fit: BoxFit.cover)),
          ),
        ),
        // --- GRADIENT FÜR LESBARKEIT ---
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.1),
                  Theme.of(context).scaffoldBackgroundColor
                ],
                stops: const [0.4, 0.9],
              ),
            ),
          ),
        ),
        
        // --- HAUPT-UI ---
        SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER: Name & Protokoll
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(widget.train.name, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)), 
                        Text(
                          () {
                            switch (config.protocol) {
                              case 'mould_king': return 'Mould King (BLE)';
                              case 'mould_king_classic': return 'Mould King (Broadcast)';
                              case 'mould_king_rwy': return 'Mould King (RWY)';
                              case 'lego_hub': return 'LEGO Powered Up';
                              case 'lego_duplo': return 'LEGO DUPLO';
                              case 'circuit_cube': return 'Circuit Cube';
                              case 'qiqiazi': return 'Qiqiai';
                              case 'genericquadcontroller': return 'Generic';
                              default: return 'Unbekanntes Protokoll';
                            }
                          }(),
                          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary.withOpacity(0.8), fontWeight: FontWeight.w500)
                        )
                      ]
                    )
                  ),
                  SizedBox(
                    height: 60, 
                    width: 220, 
                    child: ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _toggleConnection, 
                      icon: Icon(isConnected ? Icons.link_off : Icons.link), 
                      label: Text(isConnected ? 'disconnect'.tr : 'connect'.tr, style: const TextStyle(fontWeight: FontWeight.bold)), 
                      style: ElevatedButton.styleFrom(backgroundColor: isConnected ? Colors.red.shade700 : Colors.green.shade700, foregroundColor: Colors.white)
                    )
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // FAHRSTUFEN (V & R)
              Row(children: [_buildGearButton("V1", 1, true), _buildGearButton("V2", 2, true), _buildGearButton("V3", 3, true), _buildGearButton("V4", 4, true)]),
              const SizedBox(height: 12),
              Row(children: [_buildGearButton("R1", 1, false), _buildGearButton("R2", 2, false), _buildGearButton("R3", 3, false), _buildGearButton("R4", 4, false)]),
              
              const SizedBox(height: 24),
              
              // HALT & STOP
              Row(
                children: [
                  // 1. HALT (Der normale Stopp - bleibt immer Orange)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isConnected ? () => _setGear(0, true, "0") : null, 
                      icon: const Icon(Icons.pause_circle_filled, size: 28), 
                      label: Text('halt'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), 
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20), 
                        backgroundColor: Colors.orange.shade400, 
                        foregroundColor: Colors.white
                      )
                    )
                  ), 
                  const SizedBox(width: 16), 
                  // 2. STOP / BLOCKADE (Der Notaus & Warn-Button)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isConnected ? () { 
                        widget.train.emergencyStop(); 
                        setState(() { _currentGearText = "0"; }); 
                      } : null, 
                      // ICON: Wechselt bei Blockade zu einem auffälligen Fehler-Symbol
                      icon: Icon(
                        (widget.train is LegoDuploController && (widget.train as LegoDuploController).isBlocked)
                            ? Icons.report_gmailerrorred_rounded // Aggressiveres Fehler-Icon
                            : Icons.warning_amber_rounded, 
                        size: 28
                      ), 
                      label: Text(
                        (widget.train is LegoDuploController && (widget.train as LegoDuploController).isBlocked)
                            ? 'blockade.tr' // Text ändert sich bei Fehler
                            : 'stop'.tr, 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ), 
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20), 
                        // FARBE: Wird bei Blockade zu einem hellen, blinkenden Rot
                        backgroundColor: (widget.train is LegoDuploController && (widget.train as LegoDuploController).isBlocked)
                            ? Colors.redAccent.shade400 
                            : Colors.red.shade800, 
                        foregroundColor: Colors.white,
                        // Optional: Ein dickerer Rahmen bei Blockade
                        side: (widget.train is LegoDuploController && (widget.train as LegoDuploController).isBlocked)
                            ? const BorderSide(color: Colors.white, width: 2)
                            : null,
                      )
                    )
                  )
                ]
              ),

              const SizedBox(height: 32), 

              // --- ZUBEHÖR (DYNAMIC LIGHTS & SOUNDS) ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'accessories'.tr, 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)
                  ),
                  const SizedBox(height: 12),
                  
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // --- SPEZIAL-LOGIK FÜR LEGO DUPLO ---
                      if (config.protocol == 'lego_duplo') ...[
                        // Hauptlicht an/aus (Weiß)
                        FilterChip(
                          label: Text('light'.tr), 
                          selected: widget.train.lightA > 0, 
                          onSelected: isConnected ? (val) { 
                            widget.train.setLight('A', val); 
                            setState(() {}); 
                          } : null,
                        ),
                        // Farbwechsel-Button (RGB LED)
                        ActionChip(
                          avatar: Icon(Icons.palette, size: 18, color: isConnected ? Colors.blue : null),
                          label: Text('color'.tr), // Hier evtl. 'color_cycle'.tr nutzen
                          onPressed: isConnected ? () {
                            (widget.train as LegoDuploController).cycleColor();
                            setState(() {});
                          } : null,
                        ),
                        const Divider(height: 24, thickness: 0.5),
                        // Sound-Buttons

                        // 1. HUPE (ID 7)
                        ActionChip(
                          avatar: const Icon(Icons.volume_up, size: 18),
                          label: Text('horn'.tr),
                          onPressed: isConnected 
                              ? () => (widget.train as LegoDuploController).playSound(10) 
                              : null,
                        ),

                        // 2. TANKEN / WASSER (ID 5)
                        ActionChip(
                          avatar: const Icon(Icons.ev_station, size: 18),
                          label: Text('fuel'.tr),
                          onPressed: isConnected 
                              ? () => (widget.train as LegoDuploController).playSound(7) 
                              : null,
                        ),

                        // 3. DAMPF-ZISCHEN (ID 9)
                        ActionChip(
                          avatar: const Icon(Icons.music_note, size: 18),
                          label: Text('fanfare'.tr),
                          onPressed: isConnected 
                              ? () => (widget.train as LegoDuploController).playSound(5) 
                              : null,
                        ),

                        // 4. ABFAHRT / GLOCKE (ID 10)
                        ActionChip(
                          avatar: const Icon(Icons.notifications_active, size: 18),
                          label: Text('departure'.tr),
                          onPressed: isConnected 
                              ? () => (widget.train as LegoDuploController).playSound(9) 
                              : null,
                        ),

                        // 5. BREMSE / QUIETSCHEN (ID 3)
                        ActionChip(
                          avatar: const Icon(Icons.stop_circle_outlined, size: 18),
                          label: Text('brake'.tr),
                          onPressed: isConnected 
                              ? () => (widget.train as LegoDuploController).playSound(3) 
                              : null,
                        ),
                      ]
                      
                      // --- STANDARD LOGIK FÜR ANDERE PROTOKOLLE ---
                      else ...[
                        // PORT B LOGIK
                        if (!isLego || (isLego && config.portSettings['B'] == 'light'))
                          FilterChip(
                            label: Text('light_b'.tr), 
                            selected: widget.train.lightB > 0, 
                            onSelected: isConnected ? (val) { 
                              widget.train.setLight('B', val); 
                              setState(() {}); 
                            } : null,
                          ),

                        // PORT C LOGIK
                        if (!isLego)
                          FilterChip(
                            label: Text('light_c'.tr), 
                            selected: widget.train.lightC > 0, 
                            onSelected: isConnected ? (val) { 
                              widget.train.setLight('C', val); 
                              setState(() {}); 
                            } : null,
                          ),
                      ],

                      // Invertieren-Chip (gilt für alle, außer evtl. Duplo, aber schadet dort auch nicht)
                      ActionChip(
                        avatar: const Icon(Icons.swap_horiz, size: 18), 
                        label: Text('invert'.tr), 
                        backgroundColor: widget.train.inverted ? Colors.orange.withOpacity(0.4) : null, 
                        onPressed: () { 
                          widget.train.toggleInverted(); 
                          setState(() {}); 
                        }
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 32), 
              const Divider(), 
              const SizedBox(height: 16),
              
              // NOTIZEN
              if (config.notes.isNotEmpty) ...[
                const SizedBox(height: 32), 
                Container(
                  width: double.infinity, 
                  padding: const EdgeInsets.all(16), 
                  decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.amber.withOpacity(0.15) : Colors.amber.shade50.withOpacity(0.9), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withOpacity(0.3))), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Row(children: [const Icon(Icons.description_outlined, size: 16, color: Colors.orange), const SizedBox(width: 8), Text('notes_header'.tr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange))]), 
                      const SizedBox(height: 8), 
                      Text(config.notes, style: const TextStyle(fontSize: 16, height: 1.5))
                    ]
                  )
                )
              ],
              

              
              
              // Puffer für Scroll-Freiheit (besonders wichtig wegen des FAB in der Main)
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}
