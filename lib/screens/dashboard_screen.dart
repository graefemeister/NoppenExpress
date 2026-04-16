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
import 'diagnostic_screen.dart';
import '../widgets/train_control_panel.dart';

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
      applicationVersion: "Version 1.9.8",
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