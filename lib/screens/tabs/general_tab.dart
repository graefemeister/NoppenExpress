import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../controllers/train_controller.dart';
import '../../localization.dart';

class GeneralTab extends StatelessWidget {
  final TrainConfig draft;
  final TextEditingController nameController;
  final TextEditingController macController;
  final TextEditingController notesController;
  final VoidCallback onUpdate; // Triggert setState im Parent

  const GeneralTab({
    super.key,
    required this.draft,
    required this.nameController,
    required this.macController,
    required this.notesController,
    required this.onUpdate,
  });

  Future<void> _pickImage(BuildContext context) async {
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
    final XFile? image = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);

    if (image != null) {
      String safePath = await _copyImageToPermanentStorage(image.path);
      draft.imagePath = safePath;
      onUpdate(); // Sagt dem Hauptscreen: "Neu zeichnen bitte!"
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
      return tempPath;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return ListView(
      primary: false,
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: GestureDetector(
            onTap: () => _pickImage(context),
            child: CircleAvatar(
              radius: isLandscape ? 40 : 60,
              backgroundColor: Colors.blueGrey.shade100,
              backgroundImage: draft.imagePath.isNotEmpty ? FileImage(File(draft.imagePath)) : null,
              child: draft.imagePath.isEmpty ? Icon(Icons.add_a_photo, size: 30, color: Colors.blueGrey.shade800) : null,
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        DropdownButtonFormField<String>(
          value: draft.protocol,
          decoration: InputDecoration(labelText: 'label_protocol'.tr, border: const OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'lego_hub', child: Text('LEGO Powered Up')),
            DropdownMenuItem(value: 'lego_duplo', child: Text('LEGO DUPLO')),
            DropdownMenuItem(value: 'mould_king', child: Text('Mould King (GATT)')),
            DropdownMenuItem(value: 'mould_king_classic', child: Text('Mould King 4.0 (Broadcast)')),
            //DropdownMenuItem(value: 'buwizz2', child: Text('Buwizz 2.0')),
            DropdownMenuItem(value: 'pfxbrick', child: Text('PFxBrick')),
            DropdownMenuItem(value: 'circuit_cube', child: Text('Circuit Cube')),
            DropdownMenuItem(value: 'qiqiazi', child: Text('QIQIAZI')),
            DropdownMenuItem(value: 'genericquadcontroller', child: Text('Generic Quad')),
          ],
          onChanged: (newValue) {
            if (newValue != null) {
              draft.protocol = newValue;
              
              // Standard-Ports setzen (können im Tuning-Tab angepasst werden)
              if (newValue == 'lego_duplo') {
                 draft.portSettings = {'A': 'motor'};
              } else if (newValue == 'lego_hub') {
                 draft.portSettings = {'A': 'motor', 'B': 'none'};
              } else {
                 draft.portSettings = {'A': 'motor', 'B': 'none', 'C': 'none', 'D': 'none'};
              }
              onUpdate();
            }
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: nameController, 
          decoration: InputDecoration(labelText: 'label_name'.tr, border: const OutlineInputBorder(), isDense: true)
        ),
        const SizedBox(height: 16),
        TextField(
          controller: notesController, 
          minLines: 4, maxLines: 8, 
          decoration: InputDecoration(labelText: 'label_notes'.tr, border: const OutlineInputBorder(), isDense: true, alignLabelWithHint: true)
        ),
        const SizedBox(height: 16),
        
        if (draft.protocol == 'mould_king_classic') ...[
          DropdownButtonFormField<int>(
            value: draft.channel ?? 1,
            decoration: InputDecoration(labelText: 'channel_select'.tr, border: const OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1')),
              DropdownMenuItem(value: 2, child: Text('2')),
              DropdownMenuItem(value: 3, child: Text('3')),
            ],
            onChanged: (newValue) {
              if (newValue != null) {
                draft.channel = newValue;
                onUpdate();
              }
            },
          ),
        ] else ...[
          TextField(
            controller: macController, 
            decoration: InputDecoration(labelText: 'label_mac'.tr, border: const OutlineInputBorder(), isDense: true)
          ),
        ],
        const SizedBox(height: 150), 
      ],
    );
  }
}