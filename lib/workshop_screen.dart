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
  
  // KORREKTUR: Initial auf null setzen für den "Wähl mich"-Zustand
  String? _selectedProtocol;
  String _imagePath = "";
  
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
      _selectedProtocol = config.protocol; // Beim Editieren laden wir das Protokoll
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

  String _getTemplateForProtocol(String protocol) {
    switch (protocol) {
      case 'lego_hub': return 'template_lego_hub'.tr;
      case 'mould_king': return 'template_mould_king'.tr;
      case 'circuit_cube': return 'template_circuit_cube'.tr;
      default: return "";
    }
  }

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
    } catch (e) {
      debugPrint("Scan Fehler: $e");
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _save() {
    // KORREKTUR: Validierung inklusive Protokoll-Check
    if (_nameController.text.isEmpty || _macController.text.isEmpty || _selectedProtocol == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('msg_incomplete'.tr)));
      return;
    }

    final config = TrainConfig(
      id: widget.trainToEdit?.config.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      mac: _macController.text.trim().toUpperCase(),
      imagePath: _imagePath,
      protocol: _selectedProtocol!, // Sicher da oben geprüft
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

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged, {int? divisions}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Text("$label: ${value.toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold))),
        Slider(value: value, min: min, max: max, divisions: divisions, label: value.toStringAsFixed(1), onChanged: onChanged),
      ],
    );
  }

  Widget _buildPortDropdown(String portName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: _portSettings[portName] ?? 'none',
        decoration: InputDecoration(labelText: "Port $portName", border: const OutlineInputBorder(), isDense: true),
        items: [
          DropdownMenuItem(value: 'motor', child: Text('port_motor'.tr)),
          DropdownMenuItem(value: 'motor_inv', child: Text('port_motor_inv'.tr)),
          DropdownMenuItem(value: 'light', child: Text('port_light'.tr)),
          DropdownMenuItem(value: 'none', child: Text('port_none'.tr)),
        ],
        onChanged: (v) => setState(() => _portSettings[portName] = v!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (tabContext) {
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _save,
              backgroundColor: Colors.greenAccent.shade700,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.check_circle, size: 28),
              label: Text(widget.trainToEdit == null ? 'workshop_add'.tr : 'workshop_edit'.tr),
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: false, floating: true, snap: true,
                  title: Text(widget.trainToEdit == null ? 'workshop_add'.tr : 'workshop_edit'.tr),
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
                            // KORREKTUR: Farbe auf dunkles blueGrey für maximalen Kontrast auf Hellgrau
                            child: _imagePath.isEmpty ? Icon(Icons.add_a_photo, size: 30, color: Colors.blueGrey.shade800) : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      DropdownButtonFormField<String>(
                        value: _selectedProtocol,
                        // KORREKTUR: Hint wird angezeigt, wenn value null ist
                        hint: Text('label_choose_protocol'.tr),
                        decoration: InputDecoration(labelText: 'label_protocol'.tr, border: const OutlineInputBorder(), isDense: true),
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
                            // Jetzt wird die Info IMMER beim Wechsel geladen
                            _notesController.text = _getTemplateForProtocol(_selectedProtocol!);
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _notesController, 
                        minLines: 4, 
                        maxLines: 8, 
                        decoration: InputDecoration(
                          labelText: 'label_notes'.tr, 
                          border: const OutlineInputBorder(), 
                          isDense: true, 
                          alignLabelWithHint: true,
                          hintText: "..."
                        )
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _nameController, 
                        decoration: InputDecoration(labelText: 'label_name'.tr, border: const OutlineInputBorder(), isDense: true)
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _macController, 
                        decoration: InputDecoration(labelText: 'label_mac'.tr, border: const OutlineInputBorder(), isDense: true, hintText: "AC:3E:B1...")
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
                          onTap: () { 
                            _macController.text = r.device.remoteId.toString(); 
                            if (_nameController.text.isEmpty && r.device.platformName.isNotEmpty) {
                              _nameController.text = r.device.platformName;
                            }
                            DefaultTabController.of(tabContext).animateTo(0); 
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
                      _buildSlider("V1", _v1, 0, 100, (v) => setState(() => _v1 = v), divisions: 20),
                      _buildSlider("V2", _v2, 0, 100, (v) => setState(() => _v2 = v), divisions: 20),
                      _buildSlider("V3", _v3, 0, 100, (v) => setState(() => _v3 = v), divisions: 20),
                      _buildSlider("V4", _v4, 0, 100, (v) => setState(() => _v4 = v), divisions: 20),
                      const Divider(height: 40),
                      _buildSlider('tuning_ramping'.tr, _rampStep, 0.1, 3.0, (v) => setState(() => _rampStep = v), divisions: 29),
                      _buildSlider('tuning_reverse'.tr, _reverseLimit, 0.1, 1.0, (v) => setState(() => _reverseLimit = v), divisions: 9),
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