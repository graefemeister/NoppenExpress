import 'dart:io';
import 'package:flutter/material.dart';
import '../controllers/controllers.dart';
import 'package:noppenexpress_ble/l10n/l10n_extension.dart';

class TrainControlPanel extends StatefulWidget {
  final TrainController train;
  final VoidCallback onStateChanged;
  final VoidCallback? onCouple;
  final ValueChanged<String>? onDecouple;
  final VoidCallback? onSave;

  const TrainControlPanel({
    super.key,
    required this.train,
    required this.onStateChanged,
    this.onCouple,
    this.onDecouple,
    this.onSave,
  });

  @override
  State<TrainControlPanel> createState() => _TrainControlPanelState();
}

class _TrainControlPanelState extends State<TrainControlPanel> {
  bool _isConnecting = false;
  bool _showTrimControls = false;

  @override
  void initState() {
    super.initState();
    _setupBatteryWarningListener(widget.train);
  }

  @override
  void didUpdateWidget(covariant TrainControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.train != widget.train) {
      oldWidget.train.onLowBatteryWarning = null;
      _setupBatteryWarningListener(widget.train);
    }
  }

  @override
  void dispose() {
    widget.train.onLowBatteryWarning = null;
    super.dispose();
  }

  void _setupBatteryWarningListener(TrainController train) {
    train.onLowBatteryWarning = (locoName, level) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              const Icon(Icons.battery_alert, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "${context.l10n.battery_cutoff_triggered} ($locoName: $level%)",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    };
  }

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
    widget.train.setTargetSpeed(
      newTargetAbs,
      forward: widget.train.lastDirForward,
    );
    // UI-Refresh erzwingen
    widget.onStateChanged();
  }

  void _setAbsoluteGear(int gearIndex) {
    if (!widget.train.isRunning) return;
    int speedValue = (widget.train.config.gears[gearIndex] ?? 0).toInt();
    widget.train.setTargetSpeed(
      speedValue,
      forward: widget.train.lastDirForward,
    );
    widget.onStateChanged();
  }

  Future<void> _toggleConnection() async {
    final master = widget.train;
    final slaves = master.coupledControllers;

    if (master.isRunning) {
      master.emergencyStop();
      for (final s in slaves) {
        s.emergencyStop();
        await s.disconnect();
      }
      await Future.delayed(const Duration(milliseconds: 200));
      await master.disconnect();
    } else {
      setState(() => _isConnecting = true);
      try {
        await master.connectAndInitialize();
        for (final s in slaves) {
          if (!s.isRunning) {
            try {
              await s.connectAndInitialize();
            } catch (e) {
              debugPrint("Slave ${s.name} Verbindungsfehler: $e");
            }
          }
        }
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
      case 'mould_king':
        return 'Mould King (BLE)';
      case 'mould_king_classic':
        return 'Mould King (Broadcast)';
      case 'mould_king_rwy':
        return 'Mould King (RWY)';
      case 'lego_hub':
        return 'LEGO Powered Up';
      case 'buwizz2':
        return 'BuWizz 2.0';
      case 'lego_duplo':
        return 'LEGO DUPLO';
      case 'circuit_cube':
        return 'Circuit Cube';
      case 'pfxbrick':
        return 'PFxBrick';
      case 'sbrick':
        return 'SBrick';
      case 'qiqiazi':
        return 'Qiqiazi';
      case 'genericquadcontroller':
        return 'Generic';
      default:
        return "${context.l10n.unknown_protocol} ($protocol)";
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.train.config;
    final isConnected = widget.train.isRunning;
    final isManual = config.isManualMode;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 3.0, 16.0, 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.train.name,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _getProtocolDisplayName(config.protocol),
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.7),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onCouple != null)
                          IconButton(
                            icon: Icon(
                              widget.train.isConsistMaster
                                  ? Icons.link
                                  : Icons.add_link,
                              color: widget.train.isConsistMaster
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            tooltip: widget.train.isConsistMaster
                                ? context.l10n.consist_manage_tooltip
                                : context.l10n.consist_create,
                            onPressed: widget.onCouple,
                          ),
                        if (widget.train.effectiveBatteryLevel != null) ...[
                          const SizedBox(height: 2),
                          _buildBatteryIndicator(context),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: config.imagePath.isNotEmpty
                          ? (config.imagePath.startsWith('assets/')
                                ? Image.asset(
                                    config.imagePath,
                                    width: 150,
                                    height: 85,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(config.imagePath),
                                    width: 150,
                                    height: 85,
                                    fit: BoxFit.cover,
                                  ))
                          : Container(
                              width: 150,
                              height: 85,
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: const Icon(Icons.train, size: 40),
                            ),
                    ),

                    const Spacer(),

                    ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _toggleConnection,
                      icon: _isConnecting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(isConnected ? Icons.link_off : Icons.link),
                      label: Text(
                        isConnected
                            ? (widget.train.isConsistMaster
                                ? "${context.l10n.disconnect} (${widget.train.coupledControllers.length + 1})"
                                : context.l10n.disconnect)
                            : (widget.train.isConsistMaster
                                ? "${context.l10n.connect} (${widget.train.coupledControllers.length + 1})"
                                : context.l10n.connect),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                  label: isManual
                      ? context.l10n.panel_mode_manual
                      : context.l10n.panel_mode_gears,
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
                  label: config.useRampingProfile2
                      ? context.l10n.panel_profile_2
                      : context.l10n.panel_profile_1,
                  isActive: config.useRampingProfile2,
                  activeColor: Colors.purple.shade700,
                  onTap: () {
                    setState(
                      () => config.useRampingProfile2 =
                          !config.useRampingProfile2,
                    );
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
                    "${context.l10n.actual}: ${widget.train.currentSpeed.toInt().abs()}% | ${context.l10n.target}: ${widget.train.targetSpeed.toInt().abs()}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              ElevatedButton(
                onPressed: isConnected
                    ? () {
                        widget.train.emergencyStop();
                        widget.onStateChanged();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  context.l10n.stop.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isConnected
                      ? () {
                          widget.train.setTargetSpeed(
                            0,
                            forward: widget.train.lastDirForward,
                          );
                          widget.onStateChanged();
                        }
                      : null,
                  icon: const Icon(Icons.pause_circle_filled, size: 24),
                  label: Text(
                    context.l10n.halt,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.orange.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _multiBtn(
                isManual ? "--" : "1",
                isManual ? -(config.deltaStep * 2) : 1,
                isManual,
              ),
              _multiBtn(
                isManual ? "-" : "2",
                isManual ? -config.deltaStep : 2,
                isManual,
              ),
              _multiBtn(
                isManual ? "+" : "3",
                isManual ? config.deltaStep : 3,
                isManual,
              ),
              _multiBtn(
                isManual ? "++" : "4",
                isManual ? (config.deltaStep * 2) : 4,
                isManual,
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(),

          Text(
            context.l10n.accessories,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              if (config.protocol == 'lego_duplo')
                ..._buildDuploControls(isConnected)
              else if (config.protocol == 'pfxbrick')
                ..._buildDynamicPFxControls(isConnected)
              else
                ..._buildStandardControls(isConnected, config.portSettings),
            ],
          ),

          if (widget.train.isConsistMaster) ...[
            const SizedBox(height: 20),
            _buildConsistBar(context),
          ],

          if (config.notes.isNotEmpty) ...[
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.amber.withOpacity(0.1)
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.notes_header,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    config.notes,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    ),
    ),
    if (widget.train.isConsistMaster && _showTrimControls)
      _buildTrimBottomBar(context),
    ],
    );
  }

  List<Widget> _buildDuploControls(bool isConnected) {
    final duplo = widget.train as LegoDuploController;
    return [
      FilterChip(
        label: Text(context.l10n.light),
        selected: widget.train.isLightOn, // GEFIXT: Neue Status-Variable
        onSelected: isConnected
            ? (bool val) {
                widget.train.toggleLight(val);
                setState(() {});
                widget.onStateChanged();
              }
            : null,
      ),
      _buildActionChip(
        label: context.l10n.color,
        icon: Icons.palette,
        onPressed: isConnected
            ? () {
                duplo.cycleColor();
                setState(() {});
              }
            : null,
        iconColor: isConnected ? Colors.blue : null,
      ),
      _buildActionChip(
        label: context.l10n.horn,
        icon: Icons.volume_up,
        onPressed: isConnected ? () => duplo.playSound(10) : null,
      ),
      _buildActionChip(
        label: context.l10n.fuel,
        icon: Icons.ev_station,
        onPressed: isConnected ? () => duplo.playSound(7) : null,
      ),
      _buildActionChip(
        label: context.l10n.fanfare,
        icon: Icons.music_note,
        onPressed: isConnected ? () => duplo.playSound(5) : null,
      ),
      _buildActionChip(
        label: context.l10n.brake,
        icon: Icons.stop_circle_outlined,
        onPressed: isConnected ? () => duplo.playSound(3) : null,
      ),
      _buildActionChip(
        label: context.l10n.departure,
        icon: Icons.notifications_active,
        onPressed: isConnected ? () => duplo.playSound(9) : null,
      ),
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
            ? () => pfx.triggerRemoteAction(
                action.actionId,
                channel: action.channel,
              )
            : null,
      );
    }).toList();
  }

  // GEFIXT: Komplett dynamische Zubehör-Buttons anhand der Port-Einstellungen
  List<Widget> _buildStandardControls(
    bool isConnected,
    Map<String, String> portSettings,
  ) {
    final lightPorts = portSettings.entries
        .where((entry) => entry.value.contains('light'))
        .toList();
    lightPorts.sort((a, b) => a.key.compareTo(b.key));

    final bool hasDoorPort = portSettings.values.any((role) => role == 'door');

    final List<Widget> controls = [];

    if (lightPorts.length == 1) {
      final portKey = lightPorts.first.key;
      final bool isPortOn = widget.train.isPortLightOn(portKey);
      controls.add(
        FilterChip(
          showCheckmark: false,
          selected: isPortOn,
          selectedColor: Colors.yellow.shade600,
          avatar: Icon(
            isPortOn ? Icons.lightbulb : Icons.lightbulb_outline,
            color: isPortOn ? Colors.black87 : Colors.blueGrey,
            size: 18,
          ),
          label: Text(
            context.l10n.light,
            style: TextStyle(
              color: isPortOn ? Colors.black87 : null,
              fontWeight: isPortOn
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          onSelected: isConnected
              ? (bool val) {
                  widget.train.togglePortLight(portKey, val);
                  setState(() {});
                  widget.onStateChanged();
                }
              : null,
        ),
      );
    } else if (lightPorts.length > 1) {
      for (final entry in lightPorts) {
        final portKey = entry.key;
        final bool isPortOn = widget.train.isPortLightOn(portKey);
        controls.add(
          FilterChip(
            showCheckmark: false,
            selected: isPortOn,
            selectedColor: Colors.yellow.shade600,
            avatar: Icon(
              isPortOn ? Icons.lightbulb : Icons.lightbulb_outline,
              color: isPortOn ? Colors.black87 : Colors.blueGrey,
              size: 18,
            ),
            label: Text(
              "${context.l10n.light} $portKey",
              style: TextStyle(
                color: isPortOn ? Colors.black87 : null,
                fontWeight: isPortOn
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            onSelected: isConnected
                ? (bool val) {
                    widget.train.togglePortLight(portKey, val);
                    setState(() {});
                    widget.onStateChanged();
                  }
                : null,
          ),
        );
      }
    }

    if (hasDoorPort) {
      controls.add(
        FilterChip(
          showCheckmark: false,
          selected: widget.train.isDoorActive,
          selectedColor: Colors.teal.shade300,
          avatar: Icon(
            widget.train.isDoorActive
                ? Icons.door_front_door
                : Icons.door_front_door_outlined,
            color: widget.train.isDoorActive ? Colors.white : Colors.blueGrey,
            size: 18,
          ),
          label: Text(
            context.l10n.door, // (Ggf. noch in die localizations eintragen)
            style: TextStyle(
              color: widget.train.isDoorActive ? Colors.white : null,
              fontWeight: widget.train.isDoorActive
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          onSelected: isConnected
              ? (_) {
                  widget.train.toggleDoor();
                  setState(() {});
                }
              : null,
        ),
      );
    }

    return controls;
  }

  Widget _buildBatteryIndicator(BuildContext context) {
    final level = widget.train.effectiveBatteryLevel!;
    final Color color = level < 20
        ? Colors.red.shade600
        : (level < 40 ? Colors.orange.shade700 : Colors.green.shade600);
    final IconData icon = level <= 15
        ? Icons.battery_alert
        : (level <= 30
            ? Icons.battery_2_bar
            : (level <= 60
                ? Icons.battery_4_bar
                : (level <= 85 ? Icons.battery_6_bar : Icons.battery_full)));

    String tooltip = "${context.l10n.battery_level}: $level%";
    if (widget.train.isConsistMaster && widget.train.coupledControllers.isNotEmpty) {
      final list = [
        "${widget.train.name}: ${widget.train.batteryLevel != null ? '${widget.train.batteryLevel}%' : '-'}",
        ...widget.train.coupledControllers.map(
          (s) => "${s.name}: ${s.batteryLevel != null ? '${s.batteryLevel}%' : '-'}",
        ),
      ];
      tooltip = "${context.l10n.consist_battery_lowest} ($level%)\n${list.join('\n')}";
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              "$level%",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    VoidCallback? onPressed,
    Color? iconColor,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: iconColor),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  Widget _modeToggle({
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : Colors.grey.withOpacity(0.5),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : null,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _directionToggle() {
    final bool isMoving = widget.train.currentSpeed.abs() > 0;
    final colorScheme = Theme.of(context).colorScheme;

    // Die einzige Wahrheit kommt jetzt direkt aus dem Zug
    final bool isForward = widget.train.lastDirForward;

    return GestureDetector(
      onTap: isMoving
          ? null
          : () {
              // 1. Richtung im Modell umkehren
              widget.train.lastDirForward = !isForward;

              // 2. UI zwingen, sich neu zu zeichnen (Toggle springt um)
              widget.onStateChanged();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: isMoving
              ? Colors.transparent
              : colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMoving
                ? Colors.grey.withOpacity(0.2)
                : colorScheme.primary.withOpacity(0.4),
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
          onPressed: widget.train.isRunning
              ? () {
                  // 1. Die Logik ausführen
                  if (isManual) {
                    _updateSpeed(value);
                  } else {
                    _setAbsoluteGear(value);
                  }
                  // 2. GANZ WICHTIG: Die UI informieren, dass sich SOLL/IST geändert haben
                  widget.onStateChanged();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: 1,
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildConsistBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.alt_route,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.consist,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  setState(() => _showTrimControls = !_showTrimControls);
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 14,
                        color: _showTrimControls
                            ? Colors.orange.shade700
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        context.l10n.consist_trim,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _showTrimControls
                              ? Colors.orange.shade700
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.onCouple != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: widget.onCouple,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 2),
                        Text(
                          context.l10n.consist_couple_btn,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: widget.train.config.coupledUnits.map((unit) {
              final slave = widget.train.coupledControllers
                  .where((c) => c.config.id == unit.locoId)
                  .firstOrNull;
              return _buildConsistPill(context, unit, slave);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConsistPill(BuildContext context, CoupledUnit unit, TrainController? slave) {
    final name = slave?.name ?? unit.locoId;
    final isOnline = slave?.isRunning ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOnline ? Colors.green.shade600 : Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? Colors.green : Colors.red.shade400,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            unit.isReversed ? Icons.swap_horiz : Icons.arrow_forward,
            size: 14,
            color: unit.isReversed ? Colors.orange.shade700 : Colors.blue.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (unit.isReversed) ...[
            const SizedBox(width: 4),
            Text(
              context.l10n.consist_reversed,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
          if (unit.trim != 0) ...[
            const SizedBox(width: 4),
            Text(
              "(${unit.trim > 0 ? '+' : ''}${unit.trim}%)",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: unit.trim > 0
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
              ),
            ),
          ],
          if (slave != null && !isOnline) ...[
            const SizedBox(width: 2),
            IconButton(
              icon: const Icon(Icons.refresh, size: 15),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: context.l10n.consist_reconnect,
              onPressed: () async {
                try {
                  await slave.connectAndInitialize();
                } catch (e) {
                  debugPrint("Verbindungsfehler für $name: $e");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("${context.l10n.consist_reconnect_failed} '$name': $e"),
                        backgroundColor: Colors.red.shade800,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
                if (mounted) {
                  setState(() {});
                  widget.onStateChanged();
                }
              },
            ),
          ],
          if (widget.onDecouple != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => widget.onDecouple?.call(unit.locoId),
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(2.0),
                child: Icon(Icons.close, size: 14, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrimBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.consist_trim_title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: context.l10n.close,
                onPressed: () {
                  setState(() => _showTrimControls = false);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...widget.train.config.coupledUnits.map((unit) {
            final slave = widget.train.coupledControllers
                .where((c) => c.config.id == unit.locoId)
                .firstOrNull;
            final slaveName = slave?.name ?? unit.locoId;
            final int trim = unit.trim;
            final String sign = trim > 0 ? "+" : "";

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.train,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                slaveName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: trim == 0
                              ? Colors.grey.withOpacity(0.15)
                              : (trim > 0 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "$sign$trim %",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: trim == 0
                                ? theme.colorScheme.onSurfaceVariant
                                : (trim > 0 ? Colors.green.shade700 : Colors.orange.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: "-5%",
                        onPressed: () {
                          setState(() {
                            unit.trim = (unit.trim - 5).clamp(-50, 50);
                          });
                          widget.train.reapplyConsistSpeed();
                          widget.onSave?.call();
                        },
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "-50%",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Expanded(
                        child: Slider(
                          value: unit.trim.toDouble(),
                          min: -50.0,
                          max: 50.0,
                          divisions: 100,
                          label: "$sign${unit.trim}%",
                          onChanged: (val) {
                            setState(() {
                              unit.trim = val.round();
                            });
                            widget.train.reapplyConsistSpeed();
                          },
                          onChangeEnd: (_) {
                            widget.onSave?.call();
                          },
                        ),
                      ),
                      const Text(
                        "+50%",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: "+5%",
                        onPressed: () {
                          setState(() {
                            unit.trim = (unit.trim + 5).clamp(-50, 50);
                          });
                          widget.train.reapplyConsistSpeed();
                          widget.onSave?.call();
                        },
                      ),
                      if (trim != 0) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.restart_alt, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: context.l10n.consist_reset_trim,
                          onPressed: () {
                            setState(() {
                              unit.trim = 0;
                            });
                            widget.train.reapplyConsistSpeed();
                            widget.onSave?.call();
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
