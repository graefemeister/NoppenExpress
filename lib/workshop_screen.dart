// Copyright (c) 2026 [graefemeister]
// This software is released under the GNU General Public License v3.0.

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'train_core.dart';
import 'dart:io'; 
import 'package:image_picker/image_picker.dart';
import 'localization.dart';

class WorkshopScreen extends StatefulWidget {
  final List<TrainController> existingTrains;
  final TrainController? trainToEdit;

  const WorkshopScreen({super.key, required this.existingTrains, this.trainToEdit});

  @override
  State<WorkshopScreen> createState() => _WorkshopScreenState();
}

class _WorkshopScreenState extends State<WorkshopScreen> {
  final _nameController = TextEditingController();
  final _macController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _selectedProtocol = 'mould_king';
  String _imagePath = "";
  
  // Tuning-Werte
  double _v1 = 25.0, _v2 = 50.0, _v3 = 75.0, _v4 = 100.0;
  double _rampStep = 1.0;
  double _reverseLimit = 1.0; 
  bool _autoLight = true;
  Map<String, String> _portSettings = {'A': 'motor', 'B': 'motor', 'C': 'none'};

  bool _isScanning = false;
  List<ScanResult> _bleResults = [];
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
    if (widget.trainToEdit != null) {
      final config = widget.trainToEdit!.config;
      _nameController.text = config.name;
      _macController.text = config.mac;
      _notesController.text = config.notes;
      _selectedProtocol = config.protocol;
      _imagePath = config.imagePath;
      _v1 = config.gears[1] ?? 25.0;
      _v2 = config.gears[2] ?? 50.0;
      _v3 = config.gears[3] ?? 75.0;
      _v4 = config.gears[4] ?? 100.0;
      _rampStep = config.rampStep;
      _reverseLimit = config.reverseLimit;
      _autoLight = config.autoLight;
      _portSettings = Map<String, String>.from(config.portSettings);
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _nameController.dispose();
    _macController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // --- LOGIK-METHODEN ---

  void _startScan() async {
    setState(() { _isScanning = true; _bleResults = []; });
    try {
      await FlutterBluePlus.stopScan();
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((r) {
        if (mounted) {
          setState(() {
            _bleResults = r.where((result) => result.device.platformName.isNotEmpty).toList();
          });
        }
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Scan Fehler: $e");
    } finally {
      _scanSub?.cancel();
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _save() {
    if (_nameController.text.isEmpty || _macController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('msg_incomplete'.tr)));
      return;
    }

    final config = TrainConfig(
      id: widget.trainToEdit?.config.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      mac: _macController.text.trim().toUpperCase(),
      imagePath: _imagePath,
      protocol: _selectedProtocol,
      notes: _notesController.text,
      gears: {0: 0, 1: _v1, 2: _v2, 3: _v3, 4: _v4},
      rampStep: _rampStep,
      reverseLimit: _reverseLimit,
      autoLight: _autoLight,
      portSettings: _portSettings,
    );

    TrainController newTrain;
    switch (_selectedProtocol) {
      case 'lego_hub': newTrain = LegoHubController(config); break;
      case 'circuit_cube': newTrain = CircuitCubeController(config); break;
      default: newTrain = MouldKingController(config);
    }
    Navigator.pop(context, newTrain);
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (bc) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Foto aufnehmen'), onTap: () { Navigator.pop(bc); _getImage(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Aus Galerie wählen'), onTap: () { Navigator.pop(bc); _getImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 85);
      if (image != null) setState(() => _imagePath = image.path);
    } catch (e) { debugPrint("Bildfehler: $e"); }
  }

  // --- UI HELFER ---

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Text("$label: ${value.toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold))),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _buildPortDropdown(String portName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: _portSettings[portName] ?? 'none',
        decoration: InputDecoration(labelText: "Port $portName", border: const OutlineInputBorder(), isDense: true),
        items: const [
          DropdownMenuItem(value: 'motor', child: Text("Motor")),
          DropdownMenuItem(value: 'motor_inv', child: Text("Motor (Invertiert)")),
          DropdownMenuItem(value: 'light', child: Text("Licht")),
          DropdownMenuItem(value: 'none', child: Text("Nichts")),
        ],
        onChanged: (v) => setState(() => _portSettings[portName] = v!),
      ),
    );
  }

  // --- HAUPT BUILD METHODE ---

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (tabContext) {
          return Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: false,
                  floating: true, 
                  snap: true,
                  title: Text(widget.trainToEdit == null ? 'workshop_add'.tr : 'workshop_edit'.tr),
                  actions: [
                    IconButton(onPressed: _save, icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 32))
                  ],
                  bottom: TabBar(
                    tabs: [
                      Tab(icon: const Icon(Icons.info_outline), text: 'tab_general'.tr),
                      Tab(icon: const Icon(Icons.settings_bluetooth), text: 'tab_scan'.tr),
                      Tab(icon: const Icon(Icons.tune), text: 'tab_tuning'.tr),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  // --- TAB 1: ALLGEMEIN ---
                  ListView(
                    primary: false,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: isLandscape ? 40 : 60,
                            backgroundColor: Colors.blueGrey.shade100,
                            backgroundImage: _imagePath.isNotEmpty ? FileImage(File(_imagePath)) : null,
                            child: _imagePath.isEmpty ? const Icon(Icons.add_a_photo, size: 30) : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _nameController, 
                        decoration: InputDecoration(labelText: 'label_name'.tr, border: const OutlineInputBorder(), isDense: true)
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _macController, 
                        decoration: InputDecoration(labelText: 'label_mac'.tr, border: const OutlineInputBorder(), isDense: true, hintText: "AC:3E:B1...")
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedProtocol,
                        decoration: InputDecoration(labelText: 'Protokoll', border: const OutlineInputBorder(), isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'lego_hub', child: Text('LEGO Powered Up')),
                          DropdownMenuItem(value: 'mould_king', child: Text('Mould King')),
                          DropdownMenuItem(value: 'circuit_cube', child: Text('Circuit Cube')),
                        ],
                        onChanged: (newValue) {
                          setState(() {
                            _selectedProtocol = newValue!;
                            if (_selectedProtocol != 'lego_hub') {
                              _portSettings['A'] = 'motor'; _portSettings['B'] = 'light'; _portSettings['C'] = 'light';
                            } else {
                              _portSettings['A'] = 'motor'; _portSettings['B'] = 'motor'; _portSettings['C'] = 'none';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesController, 
                        maxLines: isLandscape ? 1 : 3, 
                        decoration: InputDecoration(labelText: 'label_notes'.tr, border: const OutlineInputBorder(), isDense: true)
                      ),
                      const SizedBox(height: 250),
                    ],
                  ),

                  // --- TAB 2: SCAN ---
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isScanning ? null : _startScan,
                        icon: Icon(_isScanning ? Icons.sync : Icons.search),
                        label: Text(_isScanning ? 'scan_running'.tr : 'btn_start_scan'.tr),
                        style: ElevatedButton.styleFrom(backgroundColor: _isScanning ? null : Colors.blue.shade700, foregroundColor: Colors.white),
                      ),
                      if (_isScanning) const LinearProgressIndicator(color: Colors.cyanAccent),
                      const SizedBox(height: 15),
                      ..._bleResults.map((r) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(r.device.platformName.isEmpty ? 'unknown_device'.tr : r.device.platformName),
                          subtitle: Text(r.device.remoteId.toString()),
                          trailing: Text("${r.rssi} dBm", style: TextStyle(color: r.rssi < -80 ? Colors.red : Colors.green)),
                          onTap: () { 
                            _macController.text = r.device.remoteId.toString(); 
                            if (_nameController.text.isEmpty && r.device.platformName.isNotEmpty) {
                              _nameController.text = r.device.platformName;
                            }
                            DefaultTabController.of(tabContext).animateTo(0); 
                            ScaffoldMessenger.of(tabContext).hideCurrentSnackBar();
                            ScaffoldMessenger.of(tabContext).showSnackBar(
                              SnackBar(
                                content: Text('${r.device.platformName.isEmpty ? "Gerät" : r.device.platformName} ${'msg_selected'.tr}'),
                                backgroundColor: Colors.blue.shade800,
                                behavior: SnackBarBehavior.floating,
                                width: 350,
                                duration: const Duration(milliseconds: 1500),
                              ),
                            );
                          },
                        ),
                      )),
                    ],
                  ),

                  // --- TAB 3: TUNING ---
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_selectedProtocol == 'lego_hub') ...[
                        const Text("PORTS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const SizedBox(height: 10),
                        _buildPortDropdown('A'), _buildPortDropdown('B'),
                        const Divider(height: 40),
                      ],
                      Text('tuning_speed_levels'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      _buildSlider("V1", _v1, 0, 100, (v) => setState(() => _v1 = v)),
                      _buildSlider("V2", _v2, 0, 100, (v) => setState(() => _v2 = v)),
                      _buildSlider("V3", _v3, 0, 100, (v) => setState(() => _v3 = v)),
                      _buildSlider("V4", _v4, 0, 100, (v) => setState(() => _v4 = v)),
                      const Divider(height: 40),
                      Text('tuning_driving_behavior'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      _buildSlider('tuning_ramping'.tr, _rampStep, 0.1, 3.0, (v) => setState(() => _rampStep = v)),
                      // HIER IST DAS LIMIT WIEDER DA:
                      _buildSlider('tuning_reverse'.tr, _reverseLimit, 0.1, 1.0, (v) => setState(() => _reverseLimit = v)),
                      SwitchListTile(title: Text('tuning_auto_light'.tr), value: _autoLight, onChanged: (v) => setState(() => _autoLight = v)),
                      const SizedBox(height: 100),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}