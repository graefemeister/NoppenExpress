import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
// Passe diesen Import an deinen tatsächlichen Pfad für die Lokalisierung an:
import 'package:noppenexpress_ble/l10n/app_localizations.dart'; 

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  Future<void> _rateApp() async {
    final InAppReview inAppReview = InAppReview.instance;
    try {
      await inAppReview.openStoreListing(
        appStoreId: 'de.graefemeister.NoppenExpress',
      );
    } catch (_) {
      // Fallback über url_launcher, falls der Play Store nicht installiert ist
      final Uri playStoreUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=de.graefemeister.NoppenExpress',
      );
      await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'graefemeister@gmail.com',
      query: 'subject=${Uri.encodeComponent('Feedback: NoppenExpress')}',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _openGitHub() async {
    final Uri githubUri = Uri.parse('https://github.com/graefemeister/NoppenExpress/issues');
    try {
      await launchUrl(githubUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Optional: Fehlermeldung, falls kein Browser installiert ist
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Oder deine context.l10n Extension

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.feedbackAndRate),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          const Icon(
            Icons.train_rounded,
            size: 64,
            color: Colors.lightBlueAccent,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.feedbackTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.feedbackMessage,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Primärer Button: Im Play Store bewerten
          FilledButton.icon(
            onPressed: _rateApp,
            icon: const Icon(Icons.star_rounded),
            label: Text(l10n.rateApp),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          
          // Sekundärer Button: E-Mail schreiben
          OutlinedButton.icon(
            onPressed: _sendEmail,
            icon: const Icon(Icons.mail_outline_rounded),
            label: Text(l10n.sendEmail),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          
          // Optionaler Button: GitHub Issues für Tech-Nutzer
          TextButton.icon(
            onPressed: _openGitHub,
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('GitHub Issues / Bug melden'),
          ),
        ],
      ),
    );
  }
}