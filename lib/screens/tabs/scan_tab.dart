import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../controllers/train_controller.dart';
import '../../localization.dart';

class ScanTab extends StatefulWidget {
  final TrainConfig draft;
  final TextEditingController macController;
  final TextEditingController nameController;
  final VoidCallback onUpdate;

  const ScanTab({
    super.key,
    required this.draft,
    required this.macController,
    required this.nameController,
    required this.onUpdate,
  });

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  bool _isScanning = false;
  List<ScanResult> _bleResults = [];
  StreamSubscription? _scanSub;

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    if (widget.draft.protocol == 'mould_king_classic' || widget.draft.protocol == 'mould_king_rwy') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.bluetooth_searching, size: 80, color: Colors.blueGrey),
          const SizedBox(height: 24),
          Text(
            'scan_not_required'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
              title: Text(r.device.platformName.isEmpty ? 'unknown_device'.tr : r.device.platformName),
              subtitle: Text(r.device.remoteId.toString()),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(signalIcon, color: signalColor, size: 20),
                  Text('${r.rssi} dBm', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              onTap: () { 
                if (_isScanning) _stopScan(); 
                
                // Trage die Daten direkt in die Controller und den Draft ein!
                widget.macController.text = r.device.remoteId.toString(); 
                if (widget.nameController.text.isEmpty) {
                  widget.nameController.text = r.device.platformName;
                }
                
                widget.onUpdate(); // UI-Update anfordern
                
                // Springe automatisch zurück zum ersten Tab
                DefaultTabController.of(context).animateTo(0); 
              },
            ),
          );
        }),
      ],
    );
  }
}