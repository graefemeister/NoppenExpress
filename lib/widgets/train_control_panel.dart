import 'dart:io';
import 'package:flutter/material.dart';
import '../controllers/controllers.dart';
import '../localization.dart';

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

  bool _useManualControl = false; 

  // Wir merken uns hier nur den Zielwert der UI, damit die +/- Logik 
  // sauber funktioniert, bevor Invertierungen oder ReverseLimits greifen.
  int _uiTargetSpeed = 0;  

  Future<void> _toggleConnection() async {
    if (widget.train.isRunning) {
      widget.train.emergencyStop();
      await Future.delayed(const Duration(milliseconds: 300));
      await widget.train.disconnect();
      setState(() {
        _currentGearText = "0";
        _uiTargetSpeed = 0;
      });
    } else {
      setState(() => _isConnecting = true);
      try { await widget.train.connectAndInitialize(); } catch (e) { debugPrint("Fehler"); }
    }
    if (mounted) { setState(() => _isConnecting = false); widget.onStateChanged(); }
  }

  // --- KLASSISCHES PULT (V1-V4) ---
  void _setGear(int gear, bool forward, String label) {
    if (!widget.train.isRunning) return;
    
    widget.train.setGear(gear, forward: forward);
    setState(() {
      _currentGearText = gear == 0 ? "0" : label;
      
      // Synchronisiere _uiTargetSpeed, falls der Nutzer danach auf Manuell wechselt
      if (gear == 0) {
        _uiTargetSpeed = 0;
      } else {
        int actualSpeed = (widget.train.config.gears[gear] ?? 0).toInt();
        _uiTargetSpeed = forward ? actualSpeed : -actualSpeed;
      }
    });
  }

  // --- MANUELLES PULT (+ / -) ---
  void _updateTargetSpeed(int delta) {
    if (!widget.train.isRunning) return;
    
    final config = widget.train.config;
    int minSpeed = (config.gears[1] ?? 25).toInt();
    int maxSpeed = (config.gears[4] ?? 100).toInt();

    int newTarget = _uiTargetSpeed + delta;

    // Nulldurchgangssperre (Kein sofortiger Rückwärtsgang beim Bremsen)
    if (_uiTargetSpeed > 0 && newTarget < 0) newTarget = 0; 
    else if (_uiTargetSpeed < 0 && newTarget > 0) newTarget = 0; 

    // Min/Max Regeln anwenden
    if (newTarget > 0 && newTarget < minSpeed) newTarget = minSpeed;
    if (newTarget < 0 && newTarget > -minSpeed) newTarget = -minSpeed;
    if (_uiTargetSpeed == minSpeed && delta < 0) newTarget = 0;
    if (_uiTargetSpeed == -minSpeed && delta > 0) newTarget = 0;
    if (newTarget > maxSpeed) newTarget = maxSpeed;
    if (newTarget < -maxSpeed) newTarget = -maxSpeed;

    setState(() {
      _uiTargetSpeed = newTarget;
      _currentGearText = newTarget == 0 ? "0" : "Manuell"; 
    });

    // DEN CONTROLLER ARBEITEN LASSEN!
    widget.train.setTargetSpeed(newTarget.abs(), forward: newTarget >= 0);
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

  Widget _buildIncButton(String label, int delta, Color color) {
    return Expanded(
      child: ElevatedButton(
        onPressed: widget.train.isRunning ? () => _updateTargetSpeed(delta) : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = widget.train.isRunning;
    final config = widget.train.config; 
    
    // Falls Notstopp oder Disconnect vom Controller gemeldet wird: UI zurücksetzen
    if (widget.train.targetSpeed == 0 && _currentGearText != "0") {
      _currentGearText = "0";
      _uiTargetSpeed = 0;
    }

    final isLego = config.protocol == 'lego_hub';

    return Stack(
      children: [
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
        SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                              case 'pybricks': return 'LEGO PyBrick';
                              case 'lego_duplo': return 'LEGO DUPLO';
                              case 'circuit_cube': return 'Circuit Cube';
                              case 'qiqiazi': return 'Qiqiai';
                              case 'genericquadcontroller': return 'Generic';
                              default: return "${'unknown_protocol'.tr} (${config.protocol})";                            }
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
              const SizedBox(height: 20),

// --- DIE BEIDEN UMSCHALTER ---
Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, // Zieht die Buttons auf volle Breite
                children: [
                  // 1. Auswahl: Ramping-Profil
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false, // false = Profil I
                        icon: const Icon(Icons.speed, size: 18),
                        label: Text('panel_profile_1'.tr, style: const TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment<bool>(
                        value: true, // true = Profil II
                        icon: const Icon(Icons.fitness_center, size: 18),
                        label: Text('panel_profile_2'.tr, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {widget.train.useRampingProfile2},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        widget.train.useRampingProfile2 = newSelection.first;
                      });
                    },
                    // Optional: Farben anpassen, damit Profil II orange leuchtet
                    style: SegmentedButton.styleFrom(
                      selectedForegroundColor: widget.train.useRampingProfile2 ? Colors.orange.shade800 : Theme.of(context).colorScheme.primary,
                      selectedBackgroundColor: widget.train.useRampingProfile2 ? Colors.orange.shade100 : Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  
                  const SizedBox(height: 12), // Abstand zwischen den Buttons
                  
                  // 2. Auswahl: Steuerungs-Modus
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false, // false = Fahrstufen
                        icon: const Icon(Icons.view_column, size: 18),
                        label: Text('panel_mode_gears'.tr, style: const TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment<bool>(
                        value: true, // true = Manuell
                        icon: const Icon(Icons.tune, size: 18),
                        label: Text('panel_mode_manual'.tr, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {_useManualControl},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _useManualControl = newSelection.first;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- STEUERPULT BEREICH ---
              if (!_useManualControl) ...[
                Row(children: [_buildGearButton("V1", 1, true), _buildGearButton("V2", 2, true), _buildGearButton("V3", 3, true), _buildGearButton("V4", 4, true)]),
                const SizedBox(height: 12),
                Row(children: [_buildGearButton("R1", 1, false), _buildGearButton("R2", 2, false), _buildGearButton("R3", 3, false), _buildGearButton("R4", 4, false)]),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${'actual'.tr}: ${widget.train.currentSpeed.toInt()}",
                            style: TextStyle(
                              fontSize: 26, 
                              fontWeight: FontWeight.bold, 
                              color: widget.train.currentSpeed == 0 ? Colors.grey : Theme.of(context).colorScheme.primary
                            ),
                          ),
                          const SizedBox(width: 30),
                          Text(
                            "(${'target'.tr}: $_uiTargetSpeed)",
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.w500, 
                              color: Colors.grey.shade500
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          // HIER NUTZEN WIR DIE NEUE CONFIG VARIABLE: deltaStep
                          _buildIncButton("--", -(config.deltaStep * 2), Colors.blueGrey.shade700),
                          const SizedBox(width: 8),
                          _buildIncButton("-", -config.deltaStep, Colors.blueGrey.shade500),
                          const SizedBox(width: 16),
                          
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isConnected ? () => _updateTargetSpeed(-_uiTargetSpeed) : null,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Icon(Icons.stop_circle_outlined, size: 36),
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          _buildIncButton("+", config.deltaStep, Colors.teal.shade500),
                          const SizedBox(width: 8),
                          _buildIncButton("++", (config.deltaStep * 2), Colors.teal.shade700),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isConnected ? () {
                         _setGear(0, true, "0");
                      } : null, 
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
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isConnected ? () { 
                        widget.train.emergencyStop(); 
                        setState(() { 
                          _currentGearText = "0"; 
                          _uiTargetSpeed = 0; 
                        }); 
                      } : null, 
                      icon: Icon(
                        (widget.train is LegoDuploController && (widget.train as LegoDuploController).isBlocked)
                            ? Icons.report_gmailerrorred_rounded 
                            : Icons.warning_amber_rounded, 
                        size: 28
                      ), 
                      label: Text(
                        (widget.train is LegoDuploController && (widget.train as LegoDuploController).isBlocked)
                            ? 'blockade.tr' 
                            : 'stop'.tr, 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ), 
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20), 
                        backgroundColor: (widget.train is LegoDuploController && (widget.train as LegoDuploController).isBlocked)
                            ? Colors.redAccent.shade400 
                            : Colors.red.shade800, 
                        foregroundColor: Colors.white,
                        side: (widget.train is LegoDuploController && (widget.train as LegoDuploController).isBlocked)
                            ? const BorderSide(color: Colors.white, width: 2)
                            : null,
                      )
                    )
                  )
                ]
              ),
              const SizedBox(height: 32), 
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('accessories'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (config.protocol == 'lego_duplo') ...[
                        FilterChip(
                          label: Text('light'.tr), selected: widget.train.lightA > 0, 
                          onSelected: isConnected ? (val) { widget.train.setLight('A', val); setState(() {}); } : null,
                        ),
                        ActionChip(
                          avatar: Icon(Icons.palette, size: 18, color: isConnected ? Colors.blue : null),
                          label: Text('color'.tr), 
                          onPressed: isConnected ? () { (widget.train as LegoDuploController).cycleColor(); setState(() {}); } : null,
                        ),
                        const Divider(height: 24, thickness: 0.5),
                        ActionChip(avatar: const Icon(Icons.volume_up, size: 18), label: Text('horn'.tr), onPressed: isConnected ? () => (widget.train as LegoDuploController).playSound(10) : null),
                        ActionChip(avatar: const Icon(Icons.ev_station, size: 18), label: Text('fuel'.tr), onPressed: isConnected ? () => (widget.train as LegoDuploController).playSound(7) : null),
                        ActionChip(avatar: const Icon(Icons.music_note, size: 18), label: Text('fanfare'.tr), onPressed: isConnected ? () => (widget.train as LegoDuploController).playSound(5) : null),
                        ActionChip(avatar: const Icon(Icons.notifications_active, size: 18), label: Text('departure'.tr), onPressed: isConnected ? () => (widget.train as LegoDuploController).playSound(9) : null),
                        ActionChip(avatar: const Icon(Icons.stop_circle_outlined, size: 18), label: Text('brake'.tr), onPressed: isConnected ? () => (widget.train as LegoDuploController).playSound(3) : null),
                      ] else ...[
                        if (!isLego || (isLego && config.portSettings['B'] == 'light'))
                          FilterChip(label: Text('light_b'.tr), selected: widget.train.lightB > 0, onSelected: isConnected ? (val) { widget.train.setLight('B', val); setState(() {}); } : null),
                        if (!isLego)
                          FilterChip(label: Text('light_c'.tr), selected: widget.train.lightC > 0, onSelected: isConnected ? (val) { widget.train.setLight('C', val); setState(() {}); } : null),
                      ],
                      ActionChip(
                        avatar: const Icon(Icons.swap_horiz, size: 18), 
                        label: Text('invert'.tr), 
                        backgroundColor: widget.train.inverted ? Colors.orange.withOpacity(0.4) : null, 
                        onPressed: () { widget.train.toggleInverted(); setState(() {}); }
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32), 
              const Divider(), 
              const SizedBox(height: 16),
              if (config.notes.isNotEmpty) ...[
                const SizedBox(height: 32), 
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(16), 
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
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}