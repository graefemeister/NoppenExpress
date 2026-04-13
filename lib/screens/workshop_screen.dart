// Copyright (c) 2026 [graefemeister]
// This software is released under the GNU General Public License v3.0.

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io'; 
import 'dart:async';
import '../controllers/controllers.dart';
import '../localization.dart';

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
  
  String? _selectedProtocol;
  String _imagePath = "";
  
  double _v1 = 25.0, _v2 = 50.0, _v3 = 75.0, _v4 = 100.0;
  double _rampStep = 1.0;
  double _brakeStep = 3.0;
  int _rampDelay = 100;
  double _rampStep2 = 0.3;
  double _brakeStep2 = 1.0;
  int _rampDelay2 = 250;
  double _reverseLimit = 1.0; 
  bool _autoLight = false;
  Map<String, String> _portSettings = {'A': 'motor', 'B': 'motor', 'C': 'none'};
  int _deltaStep = 10;
  

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
      _brakeStep = config.brakeStep;
      _rampDelay = config.rampDelay;
      _rampStep2 = config.rampStep2;
      _brakeStep2 = config.brakeStep2;
      _rampDelay2 = config.rampDelay2;
      _reverseLimit = config.reverseLimit;
      _autoLight = config.autoLight;
      _portSettings = Map<String, String>.from(config.portSettings);
      _deltaStep = config.deltaStep;
      
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
      case 'pybricks': return 'template_pybricks_hub'.tr;
      case 'lego_duplo': return 'template_lego_duplo'.tr;
      case 'mould_king': return 'template_mould_king'.tr;
      case 'mould_king_classic': return 'template_mould_king_classic'.tr;
      case 'mould_king_rwy': return 'template_mould_king_rwy_controller'.tr;
      case 'circuit_cube': return 'template_circuit_cube'.tr;
      case 'qiqiazi': return 'template_mould_king'.tr;
      case 'genericquadcontroller': return 'template_mould_king'.tr;
      
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

  void _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  void _save() {
    if (_selectedProtocol == 'mould_king_classic'|| _selectedProtocol == 'mould_king_rwy') {
      _macController.text = "00:00:00:00:00:00"; 
    }

    if (_nameController.text.isEmpty || _macController.text.isEmpty || _selectedProtocol == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('msg_incomplete'.tr))
      );
      return;
    }

    final config = TrainConfig(
      id: widget.trainToEdit?.config.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      mac: _macController.text.trim().toUpperCase(),
      imagePath: _imagePath,
      protocol: _selectedProtocol!,
      notes: _notesController.text,
      gears: {0: 0, 1: _v1, 2: _v2, 3: _v3, 4: _v4},
      rampStep: _rampStep,
      brakeStep: _brakeStep,
      rampDelay: _rampDelay,
      rampStep2: _rampStep2,
      brakeStep2: _brakeStep2,
      rampDelay2: _rampDelay2,
      reverseLimit: _reverseLimit,
      autoLight: _autoLight,
      deltaStep: _deltaStep,
      portSettings: _portSettings,
    
    );

    TrainController newTrain;
    switch (_selectedProtocol) {
      case 'lego_hub': newTrain = LegoHubController(config); break;
      case 'pybricks': newTrain = PyBricksController(config); break; 
      case 'lego_duplo': newTrain = LegoDuploController(config); break; 
      case 'circuit_cube': newTrain = CircuitCubeController(config); break;
      case 'mould_king_classic': newTrain = MouldKingClassicController(config); break;
      case 'mould_king_rwy': newTrain = MouldKingRwyController(config); break;
      case 'qiqiazi': newTrain = QiqiaziController(config); break;
      case 'genericquadcontroller': newTrain = GenericQuadController(config); break;
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
            ListTile(leading: const Icon(Icons.photo_camera), title: Text('take_picture'.tr), onTap: () { Navigator.pop(bc); _getImage(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library), title: Text('choose_picture'.tr), onTap: () { Navigator.pop(bc); _getImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      String safePath = await _copyImageToPermanentStorage(image.path);
      setState(() {
        _imagePath = safePath;
      });
    }
  }

  Future<String> _copyImageToPermanentStorage(String tempPath) async {
    if (tempPath.isEmpty || tempPath.startsWith('assets/')) return tempPath;
    try {
      final File tempFile = File(tempPath);
      if (!await tempFile.exists()) return tempPath;
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = "train_img_${DateTime.now().millisecondsSinceEpoch}.png";
      final String permanentPath = "${directory.path}/$fileName";
      await tempFile.copy(permanentPath);
      return permanentPath;
    } catch (e) {
      debugPrint("Fehler beim Sichern: $e");
      return tempPath;
    }
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
                            child: _imagePath.isEmpty 
                                ? Icon(Icons.add_a_photo, size: 30, color: Colors.blueGrey.shade800) 
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: _selectedProtocol,
                        hint: Text('label_choose_protocol'.tr),
                        decoration: InputDecoration(labelText: 'label_protocol'.tr, border: const OutlineInputBorder(), isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'lego_hub', child: Text('LEGO Powered Up')),
                          DropdownMenuItem(value: 'pybricks', child: Text('PyBricks (NUS)')), 
                          DropdownMenuItem(value: 'lego_duplo', child: Text('LEGO DUPLO')),
                          DropdownMenuItem(value: 'mould_king', child: Text('Mould King')),
                          DropdownMenuItem(value: 'mould_king_classic', child: Text('Mould King 4.0 (Broadcast)')),
                          DropdownMenuItem(value: 'mould_king_rwy', child: Text('Mould King (RWY)')),
                          DropdownMenuItem(value: 'circuit_cube', child: Text('Circuit Cube')),
                          DropdownMenuItem(value: 'qiqiazi', child: Text('QIQIAZI')),
                          DropdownMenuItem(value: 'genericquadcontroller', child: Text('GenericQuadController')),
                        ],
                        onChanged: (newValue) {
                          setState(() {
                            _selectedProtocol = newValue!;
                            if (_selectedProtocol == 'lego_duplo') {
                               _portSettings = {'A': 'motor', 'B': 'light', 'C': 'none'};
                            } else if (_selectedProtocol == 'mould_king_classic') {
                              _portSettings = {'A': 'motor', 'B': 'light', 'C': 'light'};
                            } else if (_selectedProtocol != 'lego_hub') {
                              _portSettings['A'] = 'motor'; _portSettings['B'] = 'light'; _portSettings['C'] = 'light';
                            } else {
                              _portSettings['A'] = 'motor'; _portSettings['B'] = 'motor'; _portSettings['C'] = 'none';
                            }
                            _notesController.text = _getTemplateForProtocol(_selectedProtocol!);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesController, 
                        minLines: 4, maxLines: 8, 
                        decoration: InputDecoration(labelText: 'label_notes'.tr, border: const OutlineInputBorder(), isDense: true, alignLabelWithHint: true)
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController, 
                        decoration: InputDecoration(labelText: 'label_name'.tr, border: const OutlineInputBorder(), isDense: true)
                      ),
                      const SizedBox(height: 16),
                      if (!(_selectedProtocol == 'mould_king_classic'|| _selectedProtocol == 'mould_king_rwy'))...[
                        TextField(
                          controller: _macController, 
                          decoration: InputDecoration(labelText: 'label_mac'.tr, border: const OutlineInputBorder(), isDense: true, hintText: "AC:3E:B1...")
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blueGrey.shade200)),
                          child: Row(children: [const Icon(Icons.info_outline, color: Colors.blueGrey), const SizedBox(width: 12), Expanded(child: Text('info_no_mac_needed'.tr, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey)))]),
                        ),
                      ],
                      const SizedBox(height: 250), 
                    ],
                  ),
                  // --- TAB 2: SCAN ---
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_selectedProtocol == 'mould_king_classic' || _selectedProtocol == 'mould_king_rwy') ...[
                        const SizedBox(height: 100),
                        const Icon(Icons.bluetooth_searching, size: 80, color: Colors.blueGrey),
                        const SizedBox(height: 24),
                        Text(
                          'scan_not_required'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: _isScanning ? null : _startScan,
                          icon: Icon(_isScanning ? Icons.sync : Icons.search),
                          label: Text(_isScanning ? 'scan_running'.tr : 'btn_start_scan'.tr),
                        ),
                        
                        if (_isScanning) const LinearProgressIndicator(),
                        
                        const SizedBox(height: 8),

                        ..._bleResults.map((r) {
                          IconData signalIcon;
                          Color signalColor;
                          if (r.rssi > -60) {
                            signalIcon = Icons.signal_cellular_alt;
                            signalColor = Colors.green;
                          } else if (r.rssi > -80) {
                            signalIcon = Icons.signal_cellular_alt_2_bar;
                            signalColor = Colors.orange;
                          } else {
                            signalIcon = Icons.signal_cellular_alt_1_bar;
                            signalColor = Colors.red;
                          }

                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.bluetooth),
                              title: Text(r.device.platformName.isEmpty 
                                  ? 'unknown_device'.tr 
                                  : r.device.platformName),
                              subtitle: Text(r.device.remoteId.toString()),
                              
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(signalIcon, color: signalColor, size: 20),
                                  Text(
                                    '${r.rssi} dBm', 
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
                                  ),
                                ],
                              ),
                              
                              onTap: () { 
                                if (_isScanning) _stopScan(); 
                                
                                _macController.text = r.device.remoteId.toString(); 
                                if (_nameController.text.isEmpty) _nameController.text = r.device.platformName;
                                
                                DefaultTabController.of(tabContext).animateTo(0); 
                              },
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                  // --- TAB 3: TUNING ---
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_selectedProtocol == 'lego_hub') ...[
                        const Text("PORTS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        _buildPortDropdown('A'), _buildPortDropdown('B'),
                      ],
                      Text('tuning_speed_levels'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      
                      _buildSlider("V1", _v1, 0, 100, (v) {
                        setState(() {
                          _v1 = v;
                          if (_v2 < _v1) _v2 = _v1;
                          if (_v3 < _v1) _v3 = _v1;
                          if (_v4 < _v1) _v4 = _v1;
                        });
                      }, divisions: 20),

                      _buildSlider("V2", _v2, 0, 100, (v) {
                        setState(() {
                          _v2 = v;
                          if (_v1 > _v2) _v1 = _v2;
                          if (_v3 < _v2) _v3 = _v2;
                          if (_v4 < _v2) _v4 = _v2;
                        });
                      }, divisions: 20),

                      _buildSlider("V3", _v3, 0, 100, (v) {
                        setState(() {
                          _v3 = v;
                          if (_v1 > _v3) _v1 = _v3;
                          if (_v2 > _v3) _v2 = _v3;
                          if (_v4 < _v3) _v4 = _v3;
                        });
                      }, divisions: 20),

                      _buildSlider("V4", _v4, 0, 100, (v) {
                        setState(() {
                          _v4 = v;
                          if (_v1 > _v4) _v1 = _v4;
                          if (_v2 > _v4) _v2 = _v4;
                          if (_v3 > _v4) _v3 = _v4;
                        });
                      }, divisions: 20), 
                      
                      const SizedBox(height: 24),
                      
                      // --- PROFIL I (SOLO) ---
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blueGrey.withOpacity(0.2))
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.speed, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Text('tuning_profile_1'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildSlider('tuning_acceleration'.tr, _rampStep, 0.1, 5.0, (v) => setState(() => _rampStep = v), divisions: 49),
                            _buildSlider('tuning_brake'.tr, _brakeStep, 0.1, 10.0, (v) => setState(() => _brakeStep = v), divisions: 99),
                            _buildSlider('tuning_ramp_delay'.tr, _rampDelay.toDouble(), 10.0, 1500.0, (v) => setState(() => _rampDelay = v.toInt()), divisions: 149),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // --- PROFIL II (LAST) ---
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3))
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.fitness_center, size: 18, color: Colors.orange.shade800),
                                const SizedBox(width: 8),
                                Text('tuning_profile_2'.tr, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildSlider('tuning_acceleration'.tr, _rampStep2, 0.1, 5.0, (v) => setState(() => _rampStep2 = v), divisions: 49),
                            _buildSlider('tuning_brake'.tr, _brakeStep2, 0.1, 10.0, (v) => setState(() => _brakeStep2 = v), divisions: 99),
                            _buildSlider('tuning_ramp_delay'.tr, _rampDelay2.toDouble(), 10.0, 1500.0, (v) => setState(() => _rampDelay2 = v.toInt()), divisions: 149),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),

                      // --- ALLGEMEINE FEINSTEUERUNG ---
                      Text('tuning_general_settings'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 8),
                      _buildSlider('tuning_reverse'.tr, _reverseLimit, 0.1, 1.0, (v) => setState(() => _reverseLimit = v), divisions: 18),
                      _buildSlider('tuning_delta_step'.tr, _deltaStep.toDouble(), 1.0, 25.0, (v) => setState(() => _deltaStep = v.toInt()), divisions: 24),

                      if (_selectedProtocol != 'lego_duplo') ...[
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('tuning_auto_light'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)), 
                          value: _autoLight, 
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (v) => setState(() => _autoLight = v)
                        ),
                      ],
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