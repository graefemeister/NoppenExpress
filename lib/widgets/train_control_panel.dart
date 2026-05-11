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
  bool _isConnecting = false;

  void _updateSpeed(int delta) {
    if (!widget.train.isRunning) return;

    final int minSpeed = widget.train.config.vMin;
    final int maxSpeed = widget.train.config.vMax;
    
    // Wir bleiben konsequent bei int
    int currentTargetAbs = widget.train.targetSpeed.toInt().abs(); 
    int newTargetAbs;

    if (currentTargetAbs == 0 && delta > 0) {
      // Falls vMin 0 ist, nimm den ersten Delta-Schritt
      newTargetAbs = (minSpeed > 0) ? minSpeed : delta;
    } else {
      newTargetAbs = currentTargetAbs + delta;
      
      // Sanftes Einrasten auf 0 beim Runterregeln
      if (minSpeed > 0 && newTargetAbs < minSpeed && delta < 0) {
        newTargetAbs = 0;
      }
    }

    // Clamp sorgt dafür, dass wir innerhalb von 0 bis vMax bleiben
    newTargetAbs = newTargetAbs.clamp(0, maxSpeed);
    
    // Hier jetzt ohne .toDouble(), da setTargetSpeed ein int will
    widget.train.setTargetSpeed(newTargetAbs, forward: widget.train.lastDirForward);    
    // UI-Refresh erzwingen
    widget.onStateChanged();
  }

  void _setAbsoluteGear(int gearIndex) {
    if (!widget.train.isRunning) return;
    int speedValue = (widget.train.config.gears[gearIndex] ?? 0).toInt();
    widget.train.setTargetSpeed(speedValue, forward: widget.train.lastDirForward);
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

  String _getProtocolDisplayName(String protocol) {
    switch (protocol) {
      case 'mould_king': return 'Mould King (BLE)';
      case 'mould_king_classic': return 'Mould King (Broadcast)';
      case 'mould_king_rwy': return 'Mould King (RWY)';
      case 'lego_hub': return 'LEGO Powered Up';
      case 'buwizz2': return 'BuWizz 2.0';
      case 'lego_duplo': return 'LEGO DUPLO';
      case 'circuit_cube': return 'Circuit Cube';
      case 'pfxbrick': return 'PFxBrick';
      case 'qiqiazi': return 'Qiqiazi';
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

          Row(
            children: [
              _directionToggle(),
              
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

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isConnected ? () {
                    widget.train.setTargetSpeed(0, forward: widget.train.lastDirForward);
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

          Text('accessories'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              if (config.protocol == 'lego_duplo') ..._buildDuploControls(isConnected)
              else if (config.protocol == 'pfxbrick') ..._buildDynamicPFxControls(isConnected)
              
              else ..._buildStandardControls(isConnected, config.portSettings),
            ],
          ),

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

  List<Widget> _buildDuploControls(bool isConnected) {
    final duplo = widget.train as LegoDuploController;
    return [
      FilterChip(
        label: Text('light'.tr),
        selected: widget.train.isLightOn, // GEFIXT: Neue Status-Variable
        onSelected: isConnected ? (_) { 
           widget.train.toggleLight(); 
           setState(() {}); 
        } : null, 
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

  List<Widget> _buildDynamicPFxControls(bool isConnected) {
    if (widget.train is! PFxBrickController) return [];
    
    final pfx = widget.train as PFxBrickController;
    // Wir greifen auf die Liste in der Config zu
    final actions = pfx.config.pfxActions; 

    if (actions.isEmpty) return [];

    return actions.map((action) {
      return ActionChip(
        label: Text(action.label),
        backgroundColor: Colors.blueGrey.shade800,
        labelStyle: const TextStyle(color: Colors.white),
        onPressed: isConnected 
            ? () => pfx.triggerRemoteAction(action.actionId, channel: action.channel) 
            : null,
      );
    }).toList();
  }

  // GEFIXT: Komplett dynamische Zubehör-Buttons anhand der Port-Einstellungen
  List<Widget> _buildStandardControls(bool isConnected, Map<String, String> portSettings) {
    final bool hasLightPort = portSettings.values.any((role) => role.contains('light'));
    final bool hasDoorPort = portSettings.values.any((role) => role == 'door');

    return [
      if (hasLightPort)
        FilterChip(
          showCheckmark: false,
          selected: widget.train.isLightOn,
          selectedColor: Colors.yellow.shade600,
          avatar: Icon(
            widget.train.isLightOn ? Icons.lightbulb : Icons.lightbulb_outline,
            color: widget.train.isLightOn ? Colors.black87 : Colors.blueGrey,
            size: 18,
          ),
          label: Text(
            'light'.tr, 
            style: TextStyle(
              color: widget.train.isLightOn ? Colors.black87 : null,
              fontWeight: widget.train.isLightOn ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onSelected: isConnected ? (_) {
            widget.train.toggleLight();
            setState(() {});
          } : null,
        ),
        
      if (hasDoorPort)
        FilterChip(
          showCheckmark: false,
          selected: widget.train.isDoorActive,
          selectedColor: Colors.teal.shade300,
          avatar: Icon(
            widget.train.isDoorActive ? Icons.door_front_door : Icons.door_front_door_outlined,
            color: widget.train.isDoorActive ? Colors.white : Colors.blueGrey,
            size: 18,
          ),
          label: Text(
            'door'.tr, // (Ggf. noch in die localizations eintragen)
            style: TextStyle(
              color: widget.train.isDoorActive ? Colors.white : null,
              fontWeight: widget.train.isDoorActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onSelected: isConnected ? (_) {
            widget.train.toggleDoor();
            setState(() {});
          } : null,
        ),
    ];
  }

  Widget _buildActionChip({required String label, required IconData icon, VoidCallback? onPressed, Color? iconColor}) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: iconColor),
      label: Text(label),
      onPressed: onPressed,
    );
  }

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

Widget _directionToggle() {
  final bool isMoving = widget.train.currentSpeed.abs() > 0;
  final colorScheme = Theme.of(context).colorScheme;
  
  // Die einzige Wahrheit kommt jetzt direkt aus dem Zug
  final bool isForward = widget.train.lastDirForward;

  return GestureDetector(
    onTap: isMoving ? null : () {
      // 1. Richtung im Modell umkehren
      widget.train.lastDirForward = !isForward;
      
      // 2. UI zwingen, sich neu zu zeichnen (Toggle springt um)
      widget.onStateChanged();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: isMoving ? Colors.transparent : colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMoving ? Colors.grey.withOpacity(0.2) : colorScheme.primary.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAnimatedArrow(
            icon: Icons.keyboard_arrow_up_rounded,
            isActive: isForward, // Hier isForward nutzen
            isMoving: isMoving,
            colorScheme: colorScheme,
          ),
          _buildAnimatedArrow(
            icon: Icons.keyboard_arrow_down_rounded,
            isActive: !isForward, // Hier !isForward nutzen
            isMoving: isMoving,
            colorScheme: colorScheme,
          ),
        ],
      ),
    ),
  );
}

Widget _buildAnimatedArrow({
  required IconData icon,
  required bool isActive,
  required bool isMoving,
  required ColorScheme colorScheme,
}) {
  return AnimatedScale(
    // Etwas moderatere Skalierung, um Platz zu sparen
    scale: isActive ? 1.2 : 0.7,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutBack,
    child: AnimatedOpacity(
      opacity: isActive ? (isMoving ? 0.6 : 1.0) : 0.15,
      duration: const Duration(milliseconds: 300),
      child: Icon(
        icon,
        size: 26, // Von 32 auf 26 reduziert
        color: isActive ? colorScheme.primary : Colors.grey,
      ),
    ),
  );
}

 Widget _multiBtn(String label, int value, bool isManual) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: ElevatedButton(
          onPressed: widget.train.isRunning ? () {
            // 1. Die Logik ausführen
            if (isManual) {
              _updateSpeed(value);
            } else {
              _setAbsoluteGear(value);
            }
            // 2. GANZ WICHTIG: Die UI informieren, dass sich SOLL/IST geändert haben
            widget.onStateChanged(); 
          } : null,
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