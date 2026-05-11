import 'package:flutter/material.dart';
import '../localization.dart';
import 'package:flutter/services.dart' show rootBundle;

class ReadmeScreen extends StatelessWidget {
  const ReadmeScreen({super.key});

  Future<String> _loadReadme() async {
    try {
      // Lädt die Textdatei aus dem Assets-Ordner
      return await rootBundle.loadString('assets/readme.txt');
    } catch (e) {
      return 'readme_error'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    // DER FIX: Wir wickeln das gesamte Scaffold in eine SafeArea.
    // Das schiebt sowohl die AppBar als auch den Text vom Rand weg, 
    // falls dort das Punch-Hole sitzt.
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text('readme'.tr),
        ),
        body: FutureBuilder<String>(
          future: _loadReadme(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            
            return SingleChildScrollView(
              child: Container(
                // Zwingt den Container auf volle Breite, damit man überall wischen kann
                width: double.infinity, 
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  snapshot.data!, 
                  style: const TextStyle(
                    fontSize: 14, 
                    height: 1.5,
                    // Wichtig für die ASCII-Art Lokomotive!
                    fontFamily: 'monospace', 
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}