import 'dart:io';
import 'package:flutter/material.dart';
import '../controllers/controllers.dart';
import '../controllers/train_controller.dart';
import '../localization.dart';

class TrainControlPanel extends StatefulWidget {
  final TrainController train;
  final VoidCallback onStateChanged;

  const TrainControlPanel({
    super.key,
    required this.train,
    required this.onStateChanged,
  });

  @override
  State<TrainControlPanel> createState() => _TrainControlPanelState();
}

class _TrainControlPanelState extends State<TrainControlPanel> {
  bool _forwardDirection = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    // Beim allerersten Öffnen des Panels die Richtung aus dem Controller lesen
    _syncDirection();
  }

  @override
  void didUpdateWidget(covariant TrainControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Wenn in der TrainBar oben eine andere Lok angetippt wird...
    if (oldWidget.train != widget.train) {
      setState(() {
        // ...überschreiben wir die lokale UI-Richtung mit der der neuen Lok
        _syncDirection();
      });
    }
  }

  void _syncDirection() {
    // Greift direkt auf den perfekten State deines TrainControllers zu!
    _forwardDirection = widget.train.lastDirForward;
  }

  void _updateSpeed(int delta) {
    if (!widget.train.isRunning) return;

    // NEU: Wir ziehen uns direkt die sauberen Limits aus der Config
    final int minSpeed = widget.train.config.vMin;
    final int maxSpeed = widget.train.config.vMax;
    
    int currentTargetAbs = widget.train.targetSpeed.toInt().abs(); 
    int newTargetAbs;

    if (currentTargetAbs == 0 && delta > 0) {
      // Start aus dem Stand: Springe direkt auf Vmin
      newTargetAbs = minSpeed;
    } else {
      newTargetAbs = currentTargetAbs + delta;
      
      // Unter Vmin beim Bremsen -> Direkt auf 0 (Stopp)
      if (newTargetAbs < minSpeed && delta < 0) {
        newTargetAbs = 0;
      }
    }

    // NEU: clamp() sorgt dafür, dass wir niemals über Vmax hinausschießen
    newTargetAbs = newTargetAbs.clamp(0, maxSpeed);
    
    widget.train.setTargetSpeed(newTargetAbs, forward: _forwardDirection);
    widget.onStateChanged();
  }

  void _setAbsoluteGear(int gearIndex) {
    if (!widget.train.isRunning) return;
    int speedValue = (widget.train.config.gears[gearIndex] ?? 0).toInt();
    widget.train.setTargetSpeed(speedValue, forward: _forwardDirection);
    widget.onStateChanged();
  }

  Future<void> _toggleConnection() async {
    if (widget.train.isRunning) {
      widget.train.emergencyStop();
      await Future.delayed(const Duration(milliseconds: 300));
      await widget.train.disconnect();
    } else {
      setState(() => _isConnecting = true);
      try {
        await widget.train.connectAndInitialize();
      } catch (e) {
        debugPrint("Verbindungsfehler: $e");
      }
    }
    if (mounted) {
      setState(() => _isConnecting = false);
      widget.onStateChanged();
    }
  }

  // Aus dem build-Block ausgelagert, um unnötige Neudefinitionen zu vermeiden
  String _getProtocolDisplayName(String protocol) {
    switch (protocol) {
      case 'mould_king': return 'Mould King (BLE)';
      case 'mould_king_classic': return 'Mould King (Broadcast)';
      case 'mould_king_rwy': return 'Mould King (RWY)';
      case 'lego_hub': return 'LEGO Powered Up';
      case 'pybricks': return 'LEGO PyBrick';
      case 'lego_duplo': return 'LEGO DUPLO';
      case 'circuit_cube': return 'Circuit Cube';
      case 'qiqiazi': return 'Qiqiai';
      case 'genericquadcontroller': return 'Generic';
      default: return "${'unknown_protocol'.tr} ($protocol)";
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.train.config;
    final isConnected = widget.train.isRunning;
    final isManual = config.isManualMode;
    final bool isLego = config.protocol == 'lego_hub';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 3.0, 16.0, 24.0),      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ZEILE 1: Name/Protokoll oben, Bild/Button darunter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.train.name, 
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getProtocolDisplayName(config.protocol), 
                  style: TextStyle(
                    fontSize: 13, 
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                
                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: config.imagePath.isNotEmpty
                        ? (config.imagePath.startsWith('assets/')
                            ? Image.asset(config.imagePath, width: 150, height: 85, fit: BoxFit.cover)
                            : Image.file(File(config.imagePath), width: 150, height: 85, fit: BoxFit.cover))
                        : Container(
                            width: 150,
                            height: 85,
                            color: Theme.of(context).colorScheme.primaryContainer,
                            child: const Icon(Icons.train, size: 40),
                          ),
                    ),
                    
                    const Spacer(),

                    ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _toggleConnection,
                      icon: _isConnecting 
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(isConnected ? Icons.link_off : Icons.link),
                      label: Text(
                        isConnected ? 'disconnect'.tr : 'connect'.tr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected ? Colors.red.shade700 : Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // ZEILE 2: Zwei kompakte Umschalter (Stufen/Manuell & Profil 1/2)
          Row(
            children: [
              Expanded(
                child: _modeToggle(
                  label: isManual ? 'panel_mode_manual'.tr : 'panel_mode_gears'.tr,
                  isActive: isManual,
                  activeColor: Colors.blue.shade800,
                  onTap: () {
                    setState(() => config.isManualMode = !isManual);
                    widget.onStateChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeToggle(
                  label: config.useRampingProfile2 ? 'panel_profile_2'.tr : 'panel_profile_1'.tr,
                  isActive: config.useRampingProfile2,
                  activeColor: Colors.purple.shade700,
                  onTap: () {
                    setState(() => config.useRampingProfile2 = !config.useRampingProfile2);
                    widget.onStateChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ZEILE 3: [<] [>] [IST/SOLL] [NOTHALT/STOP]
          Row(
            children: [
              _dirBtn(Icons.arrow_back_ios_new, false),
              const SizedBox(width: 4),
              _dirBtn(Icons.arrow_forward_ios, true),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(
                    "${'actual'.tr}: ${widget.train.currentSpeed.toInt().abs()}% | ${'target'.tr}: ${widget.train.targetSpeed.toInt().abs()}%",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),

              ElevatedButton(
                onPressed: isConnected ? () { widget.train.emergencyStop(); widget.onStateChanged(); } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('stop'.tr.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ZEILE 4: [Halt (Orange)] [1/--] [2/-] [3/+] [4/++]
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isConnected ? () {
                    widget.train.setTargetSpeed(0, forward: _forwardDirection);
                    widget.onStateChanged();
                  } : null,
                  icon: const Icon(Icons.pause_circle_filled, size: 24),
                  label: Text('halt'.tr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.orange.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _multiBtn(isManual ? "--" : "1", isManual ? -(config.deltaStep * 2) : 1, isManual),
              _multiBtn(isManual ? "-" : "2", isManual ? -config.deltaStep : 2, isManual),
              _multiBtn(isManual ? "+" : "3", isManual ? config.deltaStep : 3, isManual),
              _multiBtn(isManual ? "++" : "4", isManual ? (config.deltaStep * 2) : 4, isManual),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(),

          // ZUBEHÖR & ACCESSORIES
          Text('accessories'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              if (config.protocol == 'lego_duplo') ..._buildDuploControls(isConnected),
              if (config.protocol != 'lego_duplo') ..._buildStandardControls(isConnected, isLego, config.portSettings),
            ],
          ),

          // NOTIZEN
          if (config.notes.isNotEmpty) ...[
            const SizedBox(height: 32),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.amber.withOpacity(0.1) : Colors.amber.shade50, 
                borderRadius: BorderRadius.circular(10), 
                border: Border.all(color: Colors.amber.withOpacity(0.3))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Icon(Icons.description_outlined, size: 16, color: Colors.orange), const SizedBox(width: 8), Text('notes_header'.tr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange))]),
                  const SizedBox(height: 8),
                  Text(config.notes, style: const TextStyle(fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // --- ZUBEHÖR HILFSMETHODEN ---

  List<Widget> _buildDuploControls(bool isConnected) {
    final duplo = widget.train as LegoDuploController;
    return [
      FilterChip(
        label: Text('light'.tr),
        selected: widget.train.lightA > 0,
        onSelected: isConnected ? (val) => _handleLight('A', val) : null,
      ),
      _buildActionChip(
        label: 'color'.tr,
        icon: Icons.palette,
        onPressed: isConnected ? () { duplo.cycleColor(); setState(() {}); } : null,
        iconColor: isConnected ? Colors.blue : null,
      ),
      _buildActionChip(label: 'horn'.tr, icon: Icons.volume_up, onPressed: isConnected ? () => duplo.playSound(10) : null),
      _buildActionChip(label: 'fuel'.tr, icon: Icons.ev_station, onPressed: isConnected ? () => duplo.playSound(7) : null),
      _buildActionChip(label: 'fanfare'.tr, icon: Icons.music_note, onPressed: isConnected ? () => duplo.playSound(5) : null),
      _buildActionChip(label: 'brake'.tr, icon: Icons.stop_circle_outlined, onPressed: isConnected ? () => duplo.playSound(3) : null),
      _buildActionChip(label: 'departure'.tr, icon: Icons.notifications_active, onPressed: isConnected ? () => duplo.playSound(9) : null),     
    ];
  }

  List<Widget> _buildStandardControls(bool isConnected, bool isLego, Map<String, dynamic> portSettings) {
    final bool showLightB = !isLego || (isLego && portSettings['B'] == 'light');
    final bool isLightBOn = widget.train.lightB > 0;
    final bool isLightCOn = widget.train.lightC > 0;

    return [
      if (showLightB)
        FilterChip(
          showCheckmark: false,
          selected: isLightBOn,
          selectedColor: Colors.yellow.shade600,
          avatar: Icon(
            isLightBOn ? Icons.lightbulb : Icons.lightbulb_outline,
            color: isLightBOn ? Colors.black87 : Colors.blueGrey,
            size: 18,
          ),
          label: Text(
            'light_b'.tr,
            style: TextStyle(
              color: isLightBOn ? Colors.black87 : null,
              fontWeight: isLightBOn ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onSelected: isConnected ? (val) => _handleLight('B', val) : null,
        ),
      if (!isLego)
        FilterChip(
          showCheckmark: false,
          selected: isLightCOn,
          selectedColor: Colors.yellow.shade600,
          avatar: Icon(
            isLightCOn ? Icons.lightbulb : Icons.lightbulb_outline,
            color: isLightCOn ? Colors.black87 : Colors.blueGrey,
            size: 18,
          ),
          label: Text(
            'light_c'.tr,
            style: TextStyle(
              // Fehler behoben: Hier stand vorher widget.train.lightB
              color: isLightCOn ? Colors.black87 : null,
              fontWeight: isLightCOn ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onSelected: isConnected ? (val) => _handleLight('C', val) : null,
        ),
    ];
  }

  void _handleLight(String port, bool value) {
    widget.train.setLight(port, value);
    setState(() {});
  }

  Widget _buildActionChip({required String label, required IconData icon, VoidCallback? onPressed, Color? iconColor}) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: iconColor),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  // --- UI HILFSWIDGETS ---

  Widget _modeToggle({required String label, required bool isActive, required Color activeColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? activeColor : Colors.grey.withOpacity(0.5)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : null, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _dirBtn(IconData icon, bool forward) {
    final bool isMoving = widget.train.currentSpeed.abs() > 0;
    final bool isSelected = _forwardDirection == forward;

    return InkWell(
      onTap: isMoving ? null : () {
        setState(() => _forwardDirection = forward);
        widget.onStateChanged();
      },
      child: Opacity(
        opacity: isMoving && !isSelected ? 0.2 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2) 
                : Colors.transparent,
            border: Border.all(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : Colors.grey.withOpacity(isMoving ? 0.2 : 1.0),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon, 
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey.withOpacity(isMoving ? 0.3 : 1.0),
            size: 18
          ),
        ),
      ),
    );
  }

  Widget _multiBtn(String label, int value, bool isManual) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: ElevatedButton(
          onPressed: widget.train.isRunning ? () => isManual ? _updateSpeed(value) : _setAbsoluteGear(value) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 1,
          ),
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}