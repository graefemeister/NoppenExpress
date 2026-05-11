import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

import '../train_manager.dart';
import '../controllers/controllers.dart';
import '../localization.dart';
import 'workshop_screen.dart';
import 'settings_screen.dart';
import 'readme_screen.dart';
import '../widgets/train_control_panel.dart';
import '../settings_manager.dart';
import '../controllers/handset_manager.dart';

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

    // --- NEU: Wir hören auf die Fernbedienung ---
    HandsetManager.instance.onTrainFocused = (TrainController focusedTrain) {
      if (mounted) {
        setState(() {
          _selectedTrain = focusedTrain;
          
          // Komfort-Funktion: Wenn der User im ersten Tab (Liste) ist, 
          // springen wir automatisch zum zweiten Tab (Steuerung) rüber.
          if (_tabController.index == 0) {
             _tabController.animateTo(1);
          }
        });
      }
    };
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
    HandsetManager.instance.updateTrains(_lokListe);
  }

  void _attachTrainListener(TrainController train) {
    train.onStatusChanged = () {
      if (mounted) {
        setState(() {
            // Logik für den automatischen Wechsel:
          if (!train.isRunning && _selectedTrain == train) {
            // Wir suchen die erste andere Lok in der Liste, die noch läuft
            try {
              _selectedTrain = _lokListe.firstWhere(
                (t) => t.isRunning && t != train
              );
              // Optional: Ein kurzer Hinweis, dass gewechselt wurde
            } catch (e) {
              // Keine andere Lok ist aktiv -> Panel leeren
              _selectedTrain = null;
              // Da keine Lok mehr da ist, springen wir zurück zum Listen-Tab
              if (_tabController.index == 1) {
                _tabController.animateTo(0);
              }
            }
          }
        });

        // --- NEU: Trigger für die LEGO-Fernbedienung ---
        HandsetManager.instance.updateTrains(_lokListe);
        // ------------------------------------------------

        _updateSmartWakelock();

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

  void _openWorkshop({TrainController? trainToEdit, int initialTabIndex = 0}) async {
    final TrainController? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WorkshopScreen(
        existingTrains: _lokListe, 
        trainToEdit: trainToEdit,
        initialTabIndex: initialTabIndex, // <--- Den Wert an den Workshop weitergeben!
      )),
    );

    if (result != null) {
      setState(() {
        if (trainToEdit != null) {
          // NUR trennen, wenn im Workshop eine NEUE Instanz erstellt wurde
          // (z.B. durch Protokollwechsel). Wenn result == trainToEdit, 
          // lassen wir die Finger vom disconnect!
          if (trainToEdit != result) {
            trainToEdit.disconnect();
            _attachTrainListener(result); // Neuen Listener nur bei neuem Objekt
          }

          int index = _lokListe.indexOf(trainToEdit);
          _lokListe[index] = result;
          if (_selectedTrain == trainToEdit) _selectedTrain = result;
          
        } else {
          // Ganz neue Lok
          _lokListe.add(result);
          _attachTrainListener(result);
        }
      });
      
      HandsetManager.instance.updateTrains(_lokListe);
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
      
      // 1. Loks wie gewohnt laden
      List<TrainController> imported = TrainManager.loadTrainsFromContent(content);
      
      // 2. Pfad-Check: Wir validieren jedes Bild, bevor es in die App-Liste kommt
      for (var t in imported) { 
        if (t.config.imagePath.isNotEmpty) {
          final imageFile = File(t.config.imagePath);
          if (!imageFile.existsSync()) {
            // Wenn die Datei auf diesem Gerät fehlt: Pfad leeren.
            // (Nutzt unsere neue Flexibilität aus dem TrainController)
            t.config.imagePath = ''; 
            print("Import-Info: Bild für '${t.name}' nicht gefunden. Pfad wurde bereinigt.");
          }
        }
        _attachTrainListener(t); 
      }

      // 3. Erst jetzt zur Liste hinzufügen und speichern
      setState(() { 
        _lokListe.addAll(imported); 
      });
      HandsetManager.instance.updateTrains(_lokListe);
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
      HandsetManager.instance.updateTrains(_lokListe);
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

  Future<void> _updateSmartWakelock() async {
    // 1. Erlaubt der User "Always On"?
    final userWantsWakelock = await SettingsManager.loadWakelock();
    
    // 2. Fährt aktuell mindestens eine Lok?
    final isAnyTrainRunning = _lokListe.any((train) => train.isRunning);

    // 3. Magie: Wakelock NUR aktivieren, wenn beides zutrifft!
    final shouldKeepScreenOn = userWantsWakelock && isAnyTrainRunning;
    
    await SettingsManager.setWakelock(shouldKeepScreenOn);
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: "NoppenExpress",
      applicationVersion: "Version 1.11.0",
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

  Widget _buildActiveTrainBar() {
    // Nur Loks anzeigen, die gerade verbunden/online sind
    final activeTrains = _lokListe.where((t) => t.isRunning).toList();

    if (activeTrains.length < 2) return const SizedBox.shrink();

    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ]
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: activeTrains.length,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemBuilder: (context, index) {
          final train = activeTrains[index];
          bool isSelected = (_selectedTrain == train);

          // Gleiche robuste Bild-Logik wie in deiner Liste
          Widget imageWidget;
          if (train.config.imagePath.isEmpty) {
            imageWidget = Icon(Icons.train, size: 28, color: Theme.of(context).hintColor);
          } else if (train.config.imagePath.startsWith('assets/')) {
            imageWidget = Image.asset(train.config.imagePath, fit: BoxFit.cover);
          } else {
            final file = File(train.config.imagePath);
            if (file.existsSync()) {
              imageWidget = Image.file(file, fit: BoxFit.cover);
            } else {
              imageWidget = const Icon(Icons.broken_image, size: 28);
            }
          }

          return GestureDetector(
            onTap: () => setState(() => _selectedTrain = train),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              width: 70,
              decoration: BoxDecoration(
                color: isSelected ? Colors.green.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.green : Theme.of(context).dividerColor.withOpacity(0.5),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: double.infinity,
                              child: imageWidget,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0, left: 2, right: 2),
                        child: Text(
                          train.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.green : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  // Kleines "Online"-Blinklicht in der Ecke
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).cardColor, width: 2),
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  } 

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

        Widget controlPanelWidget = _selectedTrain == null
            ? Center(child: Text('select_train'.tr))
            : TrainControlPanel(
                key: ValueKey(_selectedTrain!.config.id),
                train: _selectedTrain!,
                onStateChanged: () => setState(() {}),
              );

        Widget controlPart = isPortrait
            ? Column(
                children: [
                  _buildActiveTrainBar(), 
                  Expanded(child: controlPanelWidget), 
                  if (_selectedTrain != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openWorkshop(trainToEdit: _selectedTrain, initialTabIndex: 2),
                          icon: const Icon(Icons.edit_attributes), // Ein schickes Edit-Icon
                          label: Text(
                            'edit'.tr, // Nutzt deine bestehende Übersetzung
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            // Optional: Farben an dein Theme anpassen
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : controlPanelWidget; // Im Landscape bleibt alles wie bisher

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
                    _updateSmartWakelock(); 
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'export', child: Text('export'.tr)),
                  PopupMenuItem(value: 'import', child: Text('import'.tr)),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'readme', child: Row(children: [const Icon(Icons.menu_book, size: 20), const SizedBox(width: 8), Text('readme'.tr)])),
                  PopupMenuItem(value: 'settings', child: Row(children: [const Icon(Icons.settings, size: 20), const SizedBox(width: 8), Text('settings'.tr)])),
                  PopupMenuItem(value: 'about', child: Row(children: [const Icon(Icons.info_outline, size: 20), const SizedBox(width: 8), Text('about'.tr)])),                
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