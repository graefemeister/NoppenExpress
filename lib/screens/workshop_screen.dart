// Copyright (c) 2026 [graefemeister]
import 'package:flutter/material.dart';
import '../controllers/controllers.dart';
import '../localization.dart';

// Importiere deine neuen Tab-Dateien
import 'tabs/general_tab.dart';
import 'tabs/scan_tab.dart';
import 'tabs/tuning_tab.dart';

class WorkshopScreen extends StatefulWidget {
  final List<TrainController> existingTrains;
  final TrainController? trainToEdit;
  final int initialTabIndex;

  const WorkshopScreen({
    super.key, 
    required this.existingTrains, 
    this.trainToEdit,
    this.initialTabIndex = 0,
  });

  @override
  State<WorkshopScreen> createState() => _WorkshopScreenState();
}

class _WorkshopScreenState extends State<WorkshopScreen> {
  // Controller für Textfelder (Müssen zentral bleiben, da mehrere Tabs darauf zugreifen)
  late TextEditingController _nameController;
  late TextEditingController _macController;
  late TextEditingController _notesController;
  
  // Unser zentrales Entwurfs-Objekt. Hier fließen alle Änderungen der Tabs zusammen!
  late TrainConfig _draft;

  @override
  void initState() {
    super.initState();
    
    // Entweder laden wir die bestehende Lok, oder wir erstellen eine saubere, neue Basis
    TrainConfig baseConfig = widget.trainToEdit?.config ?? TrainConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '',
      mac: '',
      protocol: 'lego_hub', // Standard
    );

    // Klonen, damit wir nicht versehentlich die aktive Lok beim bloßen Anschauen verändern
    _draft = TrainConfig.fromMap(baseConfig.toMap());

    // Controller initialisieren
    _nameController = TextEditingController(text: _draft.name);
    _macController = TextEditingController(text: _draft.mac);
    _notesController = TextEditingController(text: _draft.notes);

    // Listener, die Änderungen an den Textfeldern direkt in den Draft schreiben
    _nameController.addListener(() => _draft.name = _nameController.text);
    _macController.addListener(() => _draft.mac = _macController.text);
    _notesController.addListener(() => _draft.notes = _notesController.text);
  } 

  @override
  void dispose() {
    _nameController.dispose();
    _macController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (_draft.protocol == 'mould_king_classic' || _draft.protocol == 'mould_king_rwy') {
      _draft.mac = "00:00:00:00:00:00"; 
    }

    if (_draft.name.isEmpty || _draft.mac.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('msg_incomplete'.tr))
      );
      return;
    }

    if (widget.trainToEdit != null) {
      // Existierende Lok updaten (Lässt laufende Timer der Basisklasse intakt!)
      widget.trainToEdit!.updateConfig(_draft);
      Navigator.pop(context, widget.trainToEdit);
    } else {
      // Neue Instanz erzeugen
      TrainController newTrain;
      switch (_draft.protocol) {
        case 'lego_hub': newTrain = LegoHubController(_draft); break;
        case 'lego_duplo': newTrain = LegoDuploController(_draft); break; 
        case 'circuit_cube': newTrain = CircuitCubeController(_draft); break;
        case 'buwizz2': newTrain = BuWizz2Controller(_draft); break;
        case 'pfxbrick': newTrain = PFxBrickController(_draft); break; 
        case 'mould_king_classic': newTrain = MouldKingClassicController(_draft); break;
        case 'qiqiazi': newTrain = QiqiaziController(_draft); break;
        case 'genericquadcontroller': newTrain = GenericQuadController(_draft); break;
        default: newTrain = MouldKingController(_draft); // 6.0 UART
      }
      Navigator.pop(context, newTrain);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _save,
          backgroundColor: Colors.greenAccent.shade700,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.check_circle, size: 28),
          label: Text(widget.trainToEdit == null ? 'workshop_add'.tr : 'workshop_edit_save'.tr),
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
              // Die ausgelagerten Tabs bekommen den Draft und die Controller übergeben!
              GeneralTab(
                draft: _draft, 
                nameController: _nameController, 
                macController: _macController, 
                notesController: _notesController,
                onUpdate: () => setState(() {}),
              ),
              ScanTab(
                draft: _draft,
                macController: _macController,
                nameController: _nameController,
                onUpdate: () => setState(() {}),
              ),
              TuningTab(
                draft: _draft,
                onUpdate: () => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    );
  }
}