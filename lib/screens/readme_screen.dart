import 'package:flutter/material.dart';
import '../l10n/l10n_extension.dart';
import 'package:flutter/services.dart' show rootBundle;

class ReadmeScreen extends StatelessWidget {
  const ReadmeScreen({super.key});

  Future<String> _loadReadme() async {
    // Lädt die Textdatei aus dem Assets-Ordner (wirft bei Fehler automatisch eine Exception)
    return await rootBundle.loadString('assets/readme.txt');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.readme),
        ),
        body: FutureBuilder<String>(
          future: _loadReadme(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(context.l10n.readme_error),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  snapshot.data!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
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
