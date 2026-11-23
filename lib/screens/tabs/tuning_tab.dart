import 'package:flutter/material.dart';
import '../../controllers/train_controller.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/pfx_action.dart';

class TuningTab extends StatelessWidget {
  final TrainConfig draft;
  final VoidCallback onUpdate;

  const TuningTab({super.key, required this.draft, required this.onUpdate});

  Map<String, String> _getRoleLabels(BuildContext context) => {
    'motor': context.l10n.port_motor,
    'motor_inv': context.l10n.port_motor_inv,
    'light_static': context.l10n.port_light,
    'light_static_inv': context.l10n.port_light_inv,
    'light_dir': context.l10n.port_light_dir,
    'light_dir_inv': context.l10n.port_light_dir_inv,
    'door': context.l10n.port_door,
    'smoke': context.l10n.port_smoke,
    'none': context.l10n.port_none,
  };

  List<String> _getAvailablePorts(String protocol) {
    String p = protocol.toLowerCase();
    if (p.contains('mould_king') &&
        !p.contains('classic') &&
        !p.contains('rwy')) {
      return ['A', 'B', 'C', 'D', 'E', 'F'];
    } else if (p.contains('circuit_cube')) {
      return ['A', 'B', 'C'];
    } else if (p.contains('lego_hub') || p.contains('pfxbrick')) {
      return ['A', 'B'];
    } else if (p.contains('lego_duplo')) {
      return ['A'];
    }
    return ['A', 'B', 'C', 'D'];
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged, {
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            "$label: ${value.toStringAsFixed(1)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(1),
          allowedInteraction: SliderInteraction.slideThumb,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // GEFIXT: Übergabe von BuildContext für Dark-Mode Support
  Widget _buildPortConfigurationCard(BuildContext context) {
    List<String> availablePorts = _getAvailablePorts(draft.protocol);
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final roleLabels = _getRoleLabels(context);

    return Card(
      elevation: 2,
      // Dynamische Hintergrundfarbe: Leichtes Grau/Blau im Light Mode, dunkle Transparenz im Dark Mode
      color: isDark
          ? Colors.blueGrey.withValues(alpha: 0.15)
          : Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tuning_hardware_title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.blueGrey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tuning_hardware_subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),

            ...availablePorts.map((port) {
              String currentValue = draft.portSettings[port] ?? 'none';
              if (!roleLabels.containsKey(currentValue)) currentValue = 'none';
              final bool isLightRole = currentValue.contains('light');
              final int maxPower = (draft.portMaxPower[port] ?? 100).clamp(1, 100);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            // Passt sich automatisch dem aktuellen Card-Hintergrund an
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.blueGrey.withValues(alpha: 0.5)
                                  : Colors.blueGrey.shade200,
                            ),
                          ),
                          child: Text(
                            port,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: isDark
                                  ? Colors.blueAccent.shade100
                                  : Colors.blueGrey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: currentValue,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Theme.of(
                                context,
                              ).cardColor, // Passt sich an
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: roleLabels.entries
                                .map(
                                  (entry) => DropdownMenuItem<String>(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                draft.portSettings[port] = newValue;
                                if (newValue.contains('light') && !draft.portMaxPower.containsKey(port)) {
                                  draft.portMaxPower[port] = 100;
                                }
                                onUpdate();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (isLightRole) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 61.0, right: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.brightness_6,
                              size: 16,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.port_max_brightness,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "$maxPower %",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 49.0),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                          ),
                          child: Slider(
                            value: maxPower.toDouble(),
                            min: 1.0,
                            max: 100.0,
                            divisions: 99,
                            label: "$maxPower%",
                            onChanged: (val) {
                              draft.portMaxPower[port] = val.round().clamp(1, 100);
                              onUpdate();
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            if (availablePorts.any((p) => (draft.portSettings[p] ?? '').contains('light'))) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.animation,
                    size: 18,
                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.tuning_light_fade,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? Colors.blueGrey.withValues(alpha: 0.5)
                            : Colors.blueGrey.shade200,
                      ),
                    ),
                    child: Text(
                      draft.lightFadeMs == 0 ? "0 ms" : "${draft.lightFadeMs} ms",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? Colors.blueAccent.shade100 : Colors.blueGrey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: draft.lightFadeMs.toDouble().clamp(0.0, 2000.0),
                min: 0.0,
                max: 2000.0,
                divisions: 40,
                label: draft.lightFadeMs == 0 ? "0 ms" : "${draft.lightFadeMs} ms",
                onChanged: (val) {
                  draft.lightFadeMs = val.round();
                  onUpdate();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PFX AKTIONEN (WORKSHOP DIALOG)
  // ==========================================
  void _showAddActionDialog(BuildContext context, {int? index}) {
    // Controller für das Textfeld
    final TextEditingController labelController = TextEditingController();

    // Deine ursprünglichen Standardwerte
    int selectedActionId = 5; // Entspricht deinem vorherigen 0x05
    int selectedChannel = 2;

    // Modus prüfen: Bearbeiten oder Neu?
    if (index != null) {
      final existingAction = draft.pfxActions[index];
      labelController.text = existingAction.label;
      selectedActionId = existingAction.actionId;
      selectedChannel = existingAction.channel;
    } else {
      labelController.text = context.l10n.new_button;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                index == null ? context.l10n.new_pfx_action : context.l10n.edit,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- LABEL ---
                  TextField(
                    controller: labelController,
                    decoration: InputDecoration(
                      labelText: context.l10n.tuning_hardware_label,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- AKTION / BUTTON ID (1-6) ---
                  DropdownButtonFormField<int>(
                    value: selectedActionId,
                    decoration: InputDecoration(
                      labelText: context.l10n.tuning_hardware_key,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 1,
                        child: Text(context.l10n.pfx_button_1),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text(context.l10n.pfx_button_2),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text(context.l10n.pfx_button_3),
                      ),
                      DropdownMenuItem(
                        value: 4,
                        child: Text(context.l10n.pfx_button_4),
                      ),
                      DropdownMenuItem(
                        value: 5,
                        child: Text(context.l10n.pfx_button_5),
                      ),
                      DropdownMenuItem(
                        value: 6,
                        child: Text(context.l10n.pfx_button_6),
                      ),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => selectedActionId = val!),
                  ),
                  const SizedBox(height: 16),

                  // --- KANAL AUSWAHL (1-4) ---
                  DropdownButtonFormField<int>(
                    // Sicherheits-Check, falls doch mal ein anderer Wert im Draft gespeichert wurde
                    value: [1, 2, 3, 4].contains(selectedChannel)
                        ? selectedChannel
                        : 1,
                    decoration: InputDecoration(
                      labelText: context.l10n.tuning_hardware_channel,
                    ),
                    items: [1, 2, 3, 4].map((ch) {
                      return DropdownMenuItem<int>(
                        value: ch,
                        child: Text("${context.l10n.channel} $ch"),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedChannel = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text(context.l10n.cancel),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  child: Text(
                    index == null ? context.l10n.add : context.l10n.btn_save,
                  ),
                  onPressed: () {
                    if (labelController.text.isNotEmpty) {
                      final updatedAction = PFxAction(
                        label: labelController.text,
                        actionId: selectedActionId,
                        channel: selectedChannel,
                      );

                      if (index == null) {
                        draft.pfxActions.add(updatedAction);
                      } else {
                        draft.pfxActions[index] = updatedAction;
                      }

                      onUpdate(); // Speichert & triggert UI-Refresh
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // PFX AKTIONEN (UI KARTE IM WORKSHOP)
  // ==========================================
  Widget _buildPFxActionsCard(BuildContext context) {
    if (draft.protocol.toLowerCase() != 'pfxbrick')
      return const SizedBox.shrink();

    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: isDark
          ? Colors.blueGrey.withValues(alpha: 0.15)
          : Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tuning_pfx_title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.blueGrey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tuning_pfx_subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),

            if (draft.pfxActions.isNotEmpty)
              ...draft.pfxActions.asMap().entries.map((entry) {
                int index = entry.key;
                var action = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    action.label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${context.l10n.channel} ${action.channel} | ${context.l10n.key} 0x${action.actionId.toRadixString(16).padLeft(2, '0').toUpperCase()}",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bearbeiten
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueGrey),
                        onPressed: () =>
                            _showAddActionDialog(context, index: index),
                      ),
                      // Löschen
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          draft.pfxActions.removeAt(index);
                          onUpdate();
                        },
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _showAddActionDialog(context),
                icon: const Icon(Icons.add),
                label: Text(context.l10n.add_new_button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // AKKUSCHUTZ (AUTO-STOPP)
  // ==========================================
  Widget _buildBatteryCutoffCard(BuildContext context) {
    if (!draft.supportsBatteryTelemetry) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int cutoff = draft.lowBatteryCutoff;

    String labelText;
    if (cutoff == 0) {
      labelText = context.l10n.tuning_battery_cutoff_disabled;
    } else if (cutoff == 10) {
      labelText = "$cutoff % (${context.l10n.tuning_battery_cutoff_recommended})";
    } else {
      labelText = "$cutoff %";
    }

    return Card(
      elevation: 2,
      color: isDark
          ? Colors.blueGrey.withValues(alpha: 0.15)
          : Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.battery_saver,
                  color: cutoff > 0 ? Colors.green.shade600 : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.tuning_battery_cutoff_title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.blueGrey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tuning_battery_cutoff_subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.tuning_battery_cutoff_title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cutoff == 0
                        ? Colors.grey.withValues(alpha: 0.2)
                        : (cutoff <= 10 ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    labelText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cutoff == 0
                          ? (isDark ? Colors.grey.shade400 : Colors.grey.shade700)
                          : (cutoff <= 10 ? Colors.green.shade700 : Colors.orange.shade800),
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: cutoff.toDouble(),
              min: 0,
              max: 25,
              divisions: 5,
              label: labelText,
              onChanged: (val) {
                draft.lowBatteryCutoff = val.round();
                onUpdate();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BUWIZZ SPEZIFISCHE EINSTELLUNGEN
  // ==========================================
  Widget _buildBuWizzPowerCard(BuildContext context) {
    if (!draft.protocol.toLowerCase().contains('buwizz')) {
      return const SizedBox.shrink();
    }

    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: isDark
          ? Colors.blueGrey.withValues(alpha: 0.15)
          : Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.buwizz_power_title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.blueGrey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.buwizz_power_subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              value: draft.buWizzPowerMode,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.bolt),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: 1,
                  child: Text(context.l10n.buwizz_power_slow),
                ),
                DropdownMenuItem(
                  value: 2,
                  child: Text(context.l10n.buwizz_power_normal),
                ),
                DropdownMenuItem(
                  value: 3,
                  child: Text(context.l10n.buwizz_power_fast),
                ),
                DropdownMenuItem(
                  value: 4,
                  child: Text(context.l10n.buwizz_power_ludicrous),
                ),
              ],
              onChanged: (int? newValue) {
                if (newValue != null) {
                  draft.buWizzPowerMode = newValue;
                  onUpdate();
                }
              },
            ),

            if (draft.buWizzPowerMode > 1)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.buwizz_power_warning,
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ==========================================
        // TUNING-BEREICH
        // ==========================================
        Text(
          context.l10n.tuning_limits,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),

        _buildSlider(context.l10n.vMin, draft.vMin.toDouble(), 0, 100, (v) {
          draft.vMin = v.toInt();
          if (draft.vMax < draft.vMin) draft.vMax = draft.vMin;
          if ((draft.gears[1] ?? 0) < draft.vMin)
            draft.gears[1] = draft.vMin.toDouble();
          if ((draft.gears[2] ?? 0) < draft.vMin)
            draft.gears[2] = draft.vMin.toDouble();
          if ((draft.gears[3] ?? 0) < draft.vMin)
            draft.gears[3] = draft.vMin.toDouble();
          if ((draft.gears[4] ?? 0) < draft.vMin)
            draft.gears[4] = draft.vMin.toDouble();
          onUpdate();
        }, divisions: 20),

        _buildSlider(context.l10n.vMax, draft.vMax.toDouble(), 0, 100, (v) {
          draft.vMax = v.toInt();
          if (draft.vMin > draft.vMax) draft.vMin = draft.vMax;
          if ((draft.gears[4] ?? 0) > draft.vMax)
            draft.gears[4] = draft.vMax.toDouble();
          if ((draft.gears[3] ?? 0) > draft.vMax)
            draft.gears[3] = draft.vMax.toDouble();
          if ((draft.gears[2] ?? 0) > draft.vMax)
            draft.gears[2] = draft.vMax.toDouble();
          if ((draft.gears[1] ?? 0) > draft.vMax)
            draft.gears[1] = draft.vMax.toDouble();
          onUpdate();
        }, divisions: 20),

        const SizedBox(height: 16),
        Text(
          context.l10n.tuning_speed_levels,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),

        _buildSlider("V1", draft.gears[1] ?? 25.0, 0, 100, (v) {
          draft.gears[1] = v;
          if (draft.vMin > v) draft.vMin = v.toInt();
          if ((draft.gears[2] ?? 0) < v) draft.gears[2] = v;
          if ((draft.gears[3] ?? 0) < v) draft.gears[3] = v;
          if ((draft.gears[4] ?? 0) < v) draft.gears[4] = v;
          onUpdate();
        }, divisions: 20),

        _buildSlider("V2", draft.gears[2] ?? 50.0, 0, 100, (v) {
          draft.gears[2] = v;
          if ((draft.gears[1] ?? 0) > v) draft.gears[1] = v;
          if (draft.vMin > (draft.gears[1] ?? 0))
            draft.vMin = (draft.gears[1] ?? 0).toInt();
          if ((draft.gears[3] ?? 0) < v) draft.gears[3] = v;
          if ((draft.gears[4] ?? 0) < v) draft.gears[4] = v;
          onUpdate();
        }, divisions: 20),

        _buildSlider("V3", draft.gears[3] ?? 75.0, 0, 100, (v) {
          draft.gears[3] = v;
          if ((draft.gears[1] ?? 0) > v) draft.gears[1] = v;
          if ((draft.gears[2] ?? 0) > v) draft.gears[2] = v;
          if (draft.vMin > (draft.gears[1] ?? 0))
            draft.vMin = (draft.gears[1] ?? 0).toInt();
          if ((draft.gears[4] ?? 0) < v) draft.gears[4] = v;
          if (draft.vMax < (draft.gears[4] ?? 0))
            draft.vMax = (draft.gears[4] ?? 0).toInt();
          onUpdate();
        }, divisions: 20),

        _buildSlider("V4", draft.gears[4] ?? 100.0, 0, 100, (v) {
          draft.gears[4] = v;
          if ((draft.gears[1] ?? 0) > v) draft.gears[1] = v;
          if ((draft.gears[2] ?? 0) > v) draft.gears[2] = v;
          if ((draft.gears[3] ?? 0) > v) draft.gears[3] = v;
          if (draft.vMin > (draft.gears[1] ?? 0))
            draft.vMin = (draft.gears[1] ?? 0).toInt();
          if (draft.vMax < v) draft.vMax = v.toInt();
          onUpdate();
        }, divisions: 20),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.tuning_profile_1,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSlider(
                context.l10n.tuning_acceleration,
                draft.rampStep.toDouble(),
                1.0,
                10.0,
                (v) {
                  draft.rampStep = v.toInt();
                  onUpdate();
                },
                divisions: 9,
              ),
              _buildSlider(
                context.l10n.tuning_brake,
                draft.brakeStep.toDouble(),
                1.0,
                10.0,
                (v) {
                  draft.brakeStep = v.toInt();
                  onUpdate();
                },
                divisions: 9,
              ),
              _buildSlider(
                context.l10n.tuning_ramp_delay,
                draft.rampDelay.toDouble(),
                10.0,
                1000.0,
                (v) {
                  draft.rampDelay = v.toInt();
                  onUpdate();
                },
                divisions: 99,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 18,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.tuning_profile_2,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSlider(
                context.l10n.tuning_acceleration,
                draft.rampStep2.toDouble(),
                1.0,
                10.0,
                (v) {
                  draft.rampStep2 = v.toInt();
                  onUpdate();
                },
                divisions: 9,
              ),
              _buildSlider(
                context.l10n.tuning_brake,
                draft.brakeStep2.toDouble(),
                1.0,
                10.0,
                (v) {
                  draft.brakeStep2 = v.toInt();
                  onUpdate();
                },
                divisions: 9,
              ),
              _buildSlider(
                context.l10n.tuning_ramp_delay,
                draft.rampDelay2.toDouble(),
                10.0,
                1000.0,
                (v) {
                  draft.rampDelay2 = v.toInt();
                  onUpdate();
                },
                divisions: 99,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _buildSlider(
          context.l10n.tuning_delta_step,
          draft.deltaStep.toDouble(),
          1.0,
          25.0,
          (v) {
            draft.deltaStep = v.toInt();
            onUpdate();
          },
          divisions: 24,
        ),

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),

        // ==========================================
        // HARDWARE & PORTS
        // ==========================================
        _buildPortConfigurationCard(context),

        const SizedBox(height: 16),

        // ==========================================
        // AKKUSCHUTZ (AUTO-STOPP)
        // ==========================================
        if (draft.supportsBatteryTelemetry) ...[
          _buildBatteryCutoffCard(context),
          const SizedBox(height: 16),
        ],

        // ==========================================
        // BUWIZZ LEISTUNGSMODUS
        // ==========================================
        _buildBuWizzPowerCard(context),

        // Fügt etwas Platz ein, falls die BuWizz-Karte sichtbar ist
        if (draft.protocol.toLowerCase().contains('buwizz'))
          const SizedBox(height: 16),

        // ==========================================
        // PFX SOUNDS & LICHTER
        // ==========================================
        _buildPFxActionsCard(context),

        const SizedBox(height: 150),
      ],
    );
  }
}
