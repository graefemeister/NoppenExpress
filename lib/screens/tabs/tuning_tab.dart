import 'package:flutter/material.dart';
import '../../controllers/train_controller.dart';
import '../../localization.dart';
import '../../models/pfx_action.dart';

class TuningTab extends StatelessWidget {
  final TrainConfig draft;
  final VoidCallback onUpdate;

  const TuningTab({
    super.key,
    required this.draft,
    required this.onUpdate,
  });

  Map<String, String> get _roleLabels => {
    'motor': 'port_motor'.tr,
    'motor_inv': 'port_motor_inv'.tr,
    'light_static': 'port_light'.tr,
    'light_dir': 'port_light_dir'.tr,
    'door': 'port_door'.tr,
    'none': 'port_none'.tr,
  };

  List<String> _getAvailablePorts(String protocol) {
    String p = protocol.toLowerCase();
    if (p.contains('mould_king') && !p.contains('classic') && !p.contains('rwy')) {
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

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged, {int? divisions}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0), 
          child: Text("$label: ${value.toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold))
        ),
        Slider(value: value, min: min, max: max, divisions: divisions, label: value.toStringAsFixed(1),allowedInteraction: SliderInteraction.slideThumb, onChanged: onChanged),
      ],
    );
  }

  // GEFIXT: Übergabe von BuildContext für Dark-Mode Support
  Widget _buildPortConfigurationCard(BuildContext context) {
    List<String> availablePorts = _getAvailablePorts(draft.protocol);
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      // Dynamische Hintergrundfarbe: Leichtes Grau/Blau im Light Mode, dunkle Transparenz im Dark Mode
      color: isDark ? Colors.blueGrey.withOpacity(0.15) : Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'tuning_hardware_title'.tr, 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white : Colors.blueGrey.shade800
              )
            ),
            const SizedBox(height: 8),
            Text(
              'tuning_hardware_subtitle'.tr, 
              style: TextStyle(
                fontSize: 14, 
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700
              )
            ),
            const SizedBox(height: 16),
            
            ...availablePorts.map((port) {
              String currentValue = draft.portSettings[port] ?? 'none';
              if (!_roleLabels.containsKey(currentValue)) currentValue = 'none';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      width: 45, height: 45, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // Passt sich automatisch dem aktuellen Card-Hintergrund an
                        color: Theme.of(context).cardColor, 
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.blueGrey.withOpacity(0.5) : Colors.blueGrey.shade200
                        ),
                      ),
                      child: Text(
                        port, 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 20, 
                          color: isDark ? Colors.blueAccent.shade100 : Colors.blueGrey.shade700
                        )
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: currentValue,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true, 
                          fillColor: Theme.of(context).cardColor, // Passt sich an
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: _roleLabels.entries.map((entry) => DropdownMenuItem<String>(
                          value: entry.key, child: Text(entry.value)
                        )).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            draft.portSettings[port] = newValue;
                            onUpdate();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
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
      labelController.text = 'new_button'.tr;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(index == null ? 'new_pfx_action'.tr : 'edit_button'.tr),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- LABEL ---
                  TextField(
                    controller: labelController,
                    decoration: InputDecoration(labelText: 'tuning_hardware_label'.tr),
                  ),
                  const SizedBox(height: 16),
                  
                  // --- AKTION / BUTTON ID (1-6) ---
                  DropdownButtonFormField<int>(
                    value: selectedActionId,
                    decoration: InputDecoration(labelText: 'tuning_hardware_key'.tr),
                    items: [
                      DropdownMenuItem(value: 1, child: Text('pfx_button_1'.tr)),
                      DropdownMenuItem(value: 2, child: Text('pfx_button_2'.tr)),
                      DropdownMenuItem(value: 3, child: Text('pfx_button_3'.tr)),
                      DropdownMenuItem(value: 4, child: Text('pfx_button_4'.tr)),
                      DropdownMenuItem(value: 5, child: Text('pfx_button_5'.tr)),
                      DropdownMenuItem(value: 6, child: Text('pfx_button_6'.tr)),
                    ],
                    onChanged: (val) => setDialogState(() => selectedActionId = val!),
                  ),
                  const SizedBox(height: 16),

                  // --- KANAL AUSWAHL (1-4) ---
                  DropdownButtonFormField<int>(
                    // Sicherheits-Check, falls doch mal ein anderer Wert im Draft gespeichert wurde
                    value: [1, 2, 3, 4].contains(selectedChannel) ? selectedChannel : 1,
                    decoration: InputDecoration(labelText: 'tuning_hardware_channel'.tr),
                    items: [1, 2, 3, 4].map((ch) {
                      return DropdownMenuItem<int>(
                        value: ch,
                        child: Text("${'channel'.tr} $ch"),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedChannel = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('cancel'.tr),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  child: Text(index == null ? 'add'.tr : 'save'.tr),
                  onPressed: () {
                    if (labelController.text.isNotEmpty) {
                      final updatedAction = PFxAction(
                        label: labelController.text, 
                        actionId: selectedActionId, 
                        channel: selectedChannel
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
          }
        );
      },
    );
  }
  // ==========================================
  // PFX AKTIONEN (UI KARTE IM WORKSHOP)
  // ==========================================
  Widget _buildPFxActionsCard(BuildContext context) {
    if (draft.protocol.toLowerCase() != 'pfxbrick') return const SizedBox.shrink();

    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      color: isDark ? Colors.blueGrey.withOpacity(0.15) : Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('tuning_pfx_title'.tr, 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.blueGrey.shade800)),
            const SizedBox(height: 8),
            Text('tuning_pfx_subtitle'.tr, 
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
            const SizedBox(height: 16),
            
            if (draft.pfxActions.isNotEmpty)
              ...draft.pfxActions.asMap().entries.map((entry) {
                 int index = entry.key;
                 var action = entry.value;
                 return ListTile(
                   contentPadding: EdgeInsets.zero,
                   title: Text(action.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                   subtitle: Text("${'channel'.tr} ${action.channel} | ${'key'.tr} 0x${action.actionId.toRadixString(16).padLeft(2, '0').toUpperCase()}"),
                   trailing: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       // Bearbeiten
                       IconButton(
                         icon: const Icon(Icons.edit, color: Colors.blueGrey),
                         onPressed: () => _showAddActionDialog(context, index: index),
                       ),
                       // Löschen
                       IconButton(
                         icon: const Icon(Icons.delete, color: Colors.red),
                         onPressed: () {
                           draft.pfxActions.removeAt(index);
                           onUpdate();
                         }
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
                label: Text('add_new_button'.tr),
              ),
            )
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
      color: isDark ? Colors.blueGrey.withOpacity(0.15) : Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'buwizz_power_title'.tr, 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white : Colors.blueGrey.shade800
              )
            ),
            const SizedBox(height: 8),
            Text(
              'buwizz_power_subtitle'.tr, 
              style: TextStyle(
                fontSize: 14, 
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700
              )
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<int>(
              value: draft.buWizzPowerMode,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.bolt),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true, 
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                DropdownMenuItem(value: 1, child: Text('buwizz_power_slow'.tr)),
                DropdownMenuItem(value: 2, child: Text('buwizz_power_normal'.tr)),
                DropdownMenuItem(value: 3, child: Text('buwizz_power_fast'.tr)),
                DropdownMenuItem(value: 4, child: Text('buwizz_power_ludicrous'.tr)),
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
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'buwizz_power_warning'.tr,
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
        Text('tuning_limits'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        
        _buildSlider('vMin'.tr, draft.vMin.toDouble(), 0, 100, (v) {
          draft.vMin = v.toInt();
          if (draft.vMax < draft.vMin) draft.vMax = draft.vMin;
          if ((draft.gears[1] ?? 0) < draft.vMin) draft.gears[1] = draft.vMin.toDouble();
          if ((draft.gears[2] ?? 0) < draft.vMin) draft.gears[2] = draft.vMin.toDouble();
          if ((draft.gears[3] ?? 0) < draft.vMin) draft.gears[3] = draft.vMin.toDouble();
          if ((draft.gears[4] ?? 0) < draft.vMin) draft.gears[4] = draft.vMin.toDouble();
          onUpdate();
        }, divisions: 20),

        _buildSlider('vMax'.tr, draft.vMax.toDouble(), 0, 100, (v) {
          draft.vMax = v.toInt();
          if (draft.vMin > draft.vMax) draft.vMin = draft.vMax;
          if ((draft.gears[4] ?? 0) > draft.vMax) draft.gears[4] = draft.vMax.toDouble();
          if ((draft.gears[3] ?? 0) > draft.vMax) draft.gears[3] = draft.vMax.toDouble();
          if ((draft.gears[2] ?? 0) > draft.vMax) draft.gears[2] = draft.vMax.toDouble();
          if ((draft.gears[1] ?? 0) > draft.vMax) draft.gears[1] = draft.vMax.toDouble();
          onUpdate();
        }, divisions: 20),
        
        const SizedBox(height: 16),
        Text('tuning_speed_levels'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        
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
          if (draft.vMin > (draft.gears[1] ?? 0)) draft.vMin = (draft.gears[1] ?? 0).toInt(); 
          if ((draft.gears[3] ?? 0) < v) draft.gears[3] = v;
          if ((draft.gears[4] ?? 0) < v) draft.gears[4] = v;
          onUpdate();
        }, divisions: 20),

        _buildSlider("V3", draft.gears[3] ?? 75.0, 0, 100, (v) {
          draft.gears[3] = v;
          if ((draft.gears[1] ?? 0) > v) draft.gears[1] = v;
          if ((draft.gears[2] ?? 0) > v) draft.gears[2] = v;
          if (draft.vMin > (draft.gears[1] ?? 0)) draft.vMin = (draft.gears[1] ?? 0).toInt();
          if ((draft.gears[4] ?? 0) < v) draft.gears[4] = v;
          if (draft.vMax < (draft.gears[4] ?? 0)) draft.vMax = (draft.gears[4] ?? 0).toInt();
          onUpdate();
        }, divisions: 20),

        _buildSlider("V4", draft.gears[4] ?? 100.0, 0, 100, (v) {
          draft.gears[4] = v;
          if ((draft.gears[1] ?? 0) > v) draft.gears[1] = v;
          if ((draft.gears[2] ?? 0) > v) draft.gears[2] = v;
          if ((draft.gears[3] ?? 0) > v) draft.gears[3] = v;
          if (draft.vMin > (draft.gears[1] ?? 0)) draft.vMin = (draft.gears[1] ?? 0).toInt();
          if (draft.vMax < v) draft.vMax = v.toInt(); 
          onUpdate();
        }, divisions: 20),
        
        const SizedBox(height: 24),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey.withOpacity(0.2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [const Icon(Icons.speed, size: 18, color: Colors.blueGrey), const SizedBox(width: 8), Text('tuning_profile_1'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))]),
              const SizedBox(height: 12),
              _buildSlider('tuning_acceleration'.tr, draft.rampStep.toDouble(), 1.0, 10.0, (v) { draft.rampStep = v.toInt(); onUpdate(); }, divisions: 9),
              _buildSlider('tuning_brake'.tr, draft.brakeStep.toDouble(), 1.0, 10.0, (v) { draft.brakeStep = v.toInt(); onUpdate(); }, divisions: 9),
              _buildSlider('tuning_ramp_delay'.tr, draft.rampDelay.toDouble(), 10.0, 1000.0, (v) { draft.rampDelay = v.toInt(); onUpdate(); }, divisions: 99),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.fitness_center, size: 18, color: Colors.orange.shade800), const SizedBox(width: 8), Text('tuning_profile_2'.tr, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800))]),
              const SizedBox(height: 12),
              _buildSlider('tuning_acceleration'.tr, draft.rampStep2.toDouble(), 1.0, 10.0, (v) { draft.rampStep2 = v.toInt(); onUpdate(); }, divisions: 9),
              _buildSlider('tuning_brake'.tr, draft.brakeStep2.toDouble(), 1.0, 10.0, (v) { draft.brakeStep2 = v.toInt(); onUpdate(); }, divisions: 9),
              _buildSlider('tuning_ramp_delay'.tr, draft.rampDelay2.toDouble(), 10.0, 1000.0, (v) { draft.rampDelay2 = v.toInt(); onUpdate(); }, divisions: 99),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _buildSlider('tuning_delta_step'.tr, draft.deltaStep.toDouble(), 1.0, 25.0, (v) { draft.deltaStep = v.toInt(); onUpdate(); }, divisions: 24),

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),

        // ==========================================
        // HARDWARE & PORTS 
        // ==========================================
        _buildPortConfigurationCard(context),

        const SizedBox(height: 16), 
        
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