import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_da.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('da'),
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('it'),
    Locale('nl'),
    Locale('pl'),
  ];

  /// No description provided for @about.
  ///
  /// In de, this message translates to:
  /// **'Über'**
  String get about;

  /// No description provided for @about_credits_text.
  ///
  /// In de, this message translates to:
  /// **'Besonderer Dank geht an J0EK3R (Ivan Murvai)\nfür das Reverse Engineering des Mould King 4.0/6.0 Protokolls.'**
  String get about_credits_text;

  /// No description provided for @about_credits_title.
  ///
  /// In de, this message translates to:
  /// **'Danksagung & Credits:'**
  String get about_credits_title;

  /// No description provided for @about_description.
  ///
  /// In de, this message translates to:
  /// **'Ein freies Hobbyprojekt für Klemmbausteinfreunde.\n\nLizenziert unter GNU GPL v3.\n\nEs besteht keine Verbindung zu den genannten Herstellern. Sämtliche Markennamen dienen ausschließlich der Beschreibung der technischen Kompatibilität und Interoperabilität.\n\nDie Bereitstellung erfolgt „wie besehen“ (as-is) ohne jegliche Gewährleistung oder Haftung für Schäden an der verwendeten Hardware (z. B. Hubs, Motoren, Fernbedienungen).'**
  String get about_description;

  /// No description provided for @about_github_btn.
  ///
  /// In de, this message translates to:
  /// **'Quellcode auf GitHub'**
  String get about_github_btn;

  /// No description provided for @accessories.
  ///
  /// In de, this message translates to:
  /// **'Zubehör:'**
  String get accessories;

  /// No description provided for @actual.
  ///
  /// In de, this message translates to:
  /// **'IST'**
  String get actual;

  /// No description provided for @add.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get add;

  /// No description provided for @add_new_button.
  ///
  /// In de, this message translates to:
  /// **'Neuen Knopf hinzufügen'**
  String get add_new_button;

  /// No description provided for @blockade.
  ///
  /// In de, this message translates to:
  /// **'Rad-Stopp'**
  String get blockade;

  /// No description provided for @brake.
  ///
  /// In de, this message translates to:
  /// **'Bremse'**
  String get brake;

  /// No description provided for @btn_connect.
  ///
  /// In de, this message translates to:
  /// **'Verbinden'**
  String get btn_connect;

  /// No description provided for @btn_disconnect.
  ///
  /// In de, this message translates to:
  /// **'Trennen'**
  String get btn_disconnect;

  /// No description provided for @btn_save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get btn_save;

  /// No description provided for @btn_start_scan.
  ///
  /// In de, this message translates to:
  /// **'HUBS FINDEN'**
  String get btn_start_scan;

  /// No description provided for @buwizz_power_title.
  ///
  /// In de, this message translates to:
  /// **'BuWizz Leistungsmodus'**
  String get buwizz_power_title;

  /// No description provided for @buwizz_power_subtitle.
  ///
  /// In de, this message translates to:
  /// **'Wird erst mit neuer Verbindung wirksam.\nAchtung: Höhere Spannungen auf eigene Gefahr nutzen!'**
  String get buwizz_power_subtitle;

  /// No description provided for @buwizz_power_slow.
  ///
  /// In de, this message translates to:
  /// **'Slow (ca. 5,2V)'**
  String get buwizz_power_slow;

  /// No description provided for @buwizz_power_normal.
  ///
  /// In de, this message translates to:
  /// **'Normal (ca. 7,2V - Standard)'**
  String get buwizz_power_normal;

  /// No description provided for @buwizz_power_fast.
  ///
  /// In de, this message translates to:
  /// **'Fast (ca. 9,2V)'**
  String get buwizz_power_fast;

  /// No description provided for @buwizz_power_ludicrous.
  ///
  /// In de, this message translates to:
  /// **'Ludicrous (ca. 11,2V)'**
  String get buwizz_power_ludicrous;

  /// No description provided for @buwizz_power_warning.
  ///
  /// In de, this message translates to:
  /// **'Erhöhte Spannung kann Überhitzung führen und Standard-Motoren zerstören.'**
  String get buwizz_power_warning;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @channel.
  ///
  /// In de, this message translates to:
  /// **'Kanal'**
  String get channel;

  /// No description provided for @choose_picture.
  ///
  /// In de, this message translates to:
  /// **'Bild auswählen'**
  String get choose_picture;

  /// No description provided for @color.
  ///
  /// In de, this message translates to:
  /// **'Farbe'**
  String get color;

  /// No description provided for @confirm_delete.
  ///
  /// In de, this message translates to:
  /// **'Wirklich löschen?'**
  String get confirm_delete;

  /// No description provided for @connect.
  ///
  /// In de, this message translates to:
  /// **'VERBINDEN'**
  String get connect;

  /// No description provided for @connecting_classic.
  ///
  /// In de, this message translates to:
  /// **'Sende Handshake (Broadcast)...'**
  String get connecting_classic;

  /// No description provided for @connection_lost.
  ///
  /// In de, this message translates to:
  /// **'Verbindung verloren zu'**
  String get connection_lost;

  /// No description provided for @controls.
  ///
  /// In de, this message translates to:
  /// **'Steuerpult'**
  String get controls;

  /// No description provided for @delete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// No description provided for @departure.
  ///
  /// In de, this message translates to:
  /// **'Abfahrt'**
  String get departure;

  /// No description provided for @design_theme.
  ///
  /// In de, this message translates to:
  /// **'Design (Dark Mode)'**
  String get design_theme;

  /// No description provided for @diagnosis.
  ///
  /// In de, this message translates to:
  /// **'Diagnose'**
  String get diagnosis;

  /// No description provided for @disconnect.
  ///
  /// In de, this message translates to:
  /// **'TRENNEN'**
  String get disconnect;

  /// No description provided for @display_always_on.
  ///
  /// In de, this message translates to:
  /// **'Display immer an'**
  String get display_always_on;

  /// No description provided for @display_always_on_desc.
  ///
  /// In de, this message translates to:
  /// **'Display bleibt nur dauerhaft an, solange mindestens eine Lok verbunden ist.'**
  String get display_always_on_desc;

  /// No description provided for @door.
  ///
  /// In de, this message translates to:
  /// **'Tür'**
  String get door;

  /// No description provided for @edit.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get edit;

  /// No description provided for @export.
  ///
  /// In de, this message translates to:
  /// **'Backup Export'**
  String get export;

  /// No description provided for @fanfare.
  ///
  /// In de, this message translates to:
  /// **'Fanfare'**
  String get fanfare;

  /// No description provided for @feedbackAndRate.
  ///
  /// In de, this message translates to:
  /// **'Feedback & Bewerten'**
  String get feedbackAndRate;

  /// No description provided for @feedbackTitle.
  ///
  /// In de, this message translates to:
  /// **'Gefällt dir NoppenExpress?'**
  String get feedbackTitle;

  /// No description provided for @feedbackMessage.
  ///
  /// In de, this message translates to:
  /// **'Diese App ist ein komplett kostenloses Open-Source-Projekt.\n\nEine Bewertung im Play Store ist die beste Unterstützung und hilft enorm dabei, das Projekt weiterzuentwickeln!\n\nHast du Wünsche, Ideen oder einen Fehler gefunden? Schreib mir gerne direkt.'**
  String get feedbackMessage;

  /// No description provided for @fuel.
  ///
  /// In de, this message translates to:
  /// **'Tanken'**
  String get fuel;

  /// No description provided for @global_stop.
  ///
  /// In de, this message translates to:
  /// **'GLOBAL STOPP'**
  String get global_stop;

  /// No description provided for @halt.
  ///
  /// In de, this message translates to:
  /// **'HALT'**
  String get halt;

  /// No description provided for @handset_connected.
  ///
  /// In de, this message translates to:
  /// **'Verbunden und aktiv'**
  String get handset_connected;

  /// No description provided for @handset_scanning.
  ///
  /// In de, this message translates to:
  /// **'Suche nach Fernbedienung...'**
  String get handset_scanning;

  /// No description provided for @handset_disconnected.
  ///
  /// In de, this message translates to:
  /// **'Nicht verbunden'**
  String get handset_disconnected;

  /// No description provided for @handset_paired_success.
  ///
  /// In de, this message translates to:
  /// **'Fernbedienung erfolgreich gekoppelt!'**
  String get handset_paired_success;

  /// No description provided for @hardware_and_setup.
  ///
  /// In de, this message translates to:
  /// **'Hardware & Einrichtung'**
  String get hardware_and_setup;

  /// No description provided for @horn.
  ///
  /// In de, this message translates to:
  /// **'Hupe'**
  String get horn;

  /// No description provided for @import.
  ///
  /// In de, this message translates to:
  /// **'Backup Import'**
  String get import;

  /// No description provided for @info_no_mac_needed.
  ///
  /// In de, this message translates to:
  /// **'Keine MAC benötigt'**
  String get info_no_mac_needed;

  /// No description provided for @invert.
  ///
  /// In de, this message translates to:
  /// **'Invertieren'**
  String get invert;

  /// No description provided for @key.
  ///
  /// In de, this message translates to:
  /// **'Taste'**
  String get key;

  /// No description provided for @label_change_photo.
  ///
  /// In de, this message translates to:
  /// **'Bild antippen zum Ändern'**
  String get label_change_photo;

  /// No description provided for @label_choose_protocol.
  ///
  /// In de, this message translates to:
  /// **'Protokoll wählen'**
  String get label_choose_protocol;

  /// No description provided for @label_mac.
  ///
  /// In de, this message translates to:
  /// **'MAC-Adresse'**
  String get label_mac;

  /// No description provided for @label_name.
  ///
  /// In de, this message translates to:
  /// **'Name der Lok'**
  String get label_name;

  /// No description provided for @label_notes.
  ///
  /// In de, this message translates to:
  /// **'Notizen'**
  String get label_notes;

  /// No description provided for @label_photo.
  ///
  /// In de, this message translates to:
  /// **'Foto wählen'**
  String get label_photo;

  /// No description provided for @label_protocol.
  ///
  /// In de, this message translates to:
  /// **'Protokoll / Hub-Typ'**
  String get label_protocol;

  /// No description provided for @lang_changed.
  ///
  /// In de, this message translates to:
  /// **'Sprache geändert'**
  String get lang_changed;

  /// No description provided for @light.
  ///
  /// In de, this message translates to:
  /// **'Licht'**
  String get light;

  /// No description provided for @light_b.
  ///
  /// In de, this message translates to:
  /// **'Licht B'**
  String get light_b;

  /// No description provided for @light_c.
  ///
  /// In de, this message translates to:
  /// **'Licht C'**
  String get light_c;

  /// No description provided for @list.
  ///
  /// In de, this message translates to:
  /// **'Lokliste'**
  String get list;

  /// No description provided for @mould_king_classic.
  ///
  /// In de, this message translates to:
  /// **'Mould King Classic (4.0)'**
  String get mould_king_classic;

  /// No description provided for @mould_king_classic_desc.
  ///
  /// In de, this message translates to:
  /// **'Broadcast-Steuerung für ältere 4.0 Hubs (Dino)'**
  String get mould_king_classic_desc;

  /// No description provided for @msg_incomplete.
  ///
  /// In de, this message translates to:
  /// **'Bitte Protokoll auswählen und ggf. MAC eintragen!'**
  String get msg_incomplete;

  /// No description provided for @msg_scan_error.
  ///
  /// In de, this message translates to:
  /// **'Scan-Fehler'**
  String get msg_scan_error;

  /// No description provided for @new_action.
  ///
  /// In de, this message translates to:
  /// **'Neue PFx-Action'**
  String get new_action;

  /// No description provided for @new_button.
  ///
  /// In de, this message translates to:
  /// **'Neuer Button'**
  String get new_button;

  /// No description provided for @new_pfx_action.
  ///
  /// In de, this message translates to:
  /// **'Neue PFx Aktion'**
  String get new_pfx_action;

  /// No description provided for @new_train.
  ///
  /// In de, this message translates to:
  /// **'Neue Lok anlegen'**
  String get new_train;

  /// No description provided for @no_trains.
  ///
  /// In de, this message translates to:
  /// **'Keine Loks vorhanden.\nNutze das \"+\" zum Anlegen.'**
  String get no_trains;

  /// No description provided for @notes_header.
  ///
  /// In de, this message translates to:
  /// **'INFOS & WARTUNG'**
  String get notes_header;

  /// No description provided for @offline.
  ///
  /// In de, this message translates to:
  /// **'GETRENNT'**
  String get offline;

  /// No description provided for @online.
  ///
  /// In de, this message translates to:
  /// **'VERBUNDEN'**
  String get online;

  /// No description provided for @panel_mode_gears.
  ///
  /// In de, this message translates to:
  /// **'Fahrstufen'**
  String get panel_mode_gears;

  /// No description provided for @panel_mode_manual.
  ///
  /// In de, this message translates to:
  /// **'Manuell (+/-)'**
  String get panel_mode_manual;

  /// No description provided for @panel_profile_1.
  ///
  /// In de, this message translates to:
  /// **'Profil I (Solo)'**
  String get panel_profile_1;

  /// No description provided for @panel_profile_2.
  ///
  /// In de, this message translates to:
  /// **'Profil II (Last)'**
  String get panel_profile_2;

  /// No description provided for @pfx_button_1.
  ///
  /// In de, this message translates to:
  /// **'Roter Knopf Links'**
  String get pfx_button_1;

  /// No description provided for @pfx_button_2.
  ///
  /// In de, this message translates to:
  /// **'Roter Knopf Rechts'**
  String get pfx_button_2;

  /// No description provided for @pfx_button_3.
  ///
  /// In de, this message translates to:
  /// **'Linkes Rad hoch'**
  String get pfx_button_3;

  /// No description provided for @pfx_button_4.
  ///
  /// In de, this message translates to:
  /// **'Linkes Rad runter'**
  String get pfx_button_4;

  /// No description provided for @pfx_button_5.
  ///
  /// In de, this message translates to:
  /// **'Rechtes Rad hoch'**
  String get pfx_button_5;

  /// No description provided for @pfx_button_6.
  ///
  /// In de, this message translates to:
  /// **'Rechtes Rad runter'**
  String get pfx_button_6;

  /// No description provided for @port_door.
  ///
  /// In de, this message translates to:
  /// **'Tür (Wechsel-Polung)'**
  String get port_door;

  /// No description provided for @port_light.
  ///
  /// In de, this message translates to:
  /// **'Licht'**
  String get port_light;

  /// No description provided for @port_light_dir.
  ///
  /// In de, this message translates to:
  /// **'Licht (Richtungsabhängig)'**
  String get port_light_dir;

  /// No description provided for @port_motor.
  ///
  /// In de, this message translates to:
  /// **'Motor'**
  String get port_motor;

  /// No description provided for @port_motor_inv.
  ///
  /// In de, this message translates to:
  /// **'Motor (Invertiert)'**
  String get port_motor_inv;

  /// No description provided for @port_none.
  ///
  /// In de, this message translates to:
  /// **'Nichts'**
  String get port_none;

  /// No description provided for @protocol_mk_classic.
  ///
  /// In de, this message translates to:
  /// **'Mould King (Classic / Broadcast)'**
  String get protocol_mk_classic;

  /// No description provided for @protocol_mk_modern.
  ///
  /// In de, this message translates to:
  /// **'Mould King (Modern / BLE)'**
  String get protocol_mk_modern;

  /// No description provided for @readme.
  ///
  /// In de, this message translates to:
  /// **'Anleitung'**
  String get readme;

  /// No description provided for @readme_error.
  ///
  /// In de, this message translates to:
  /// **'Fehler: readme.txt konnte nicht geladen werden.'**
  String get readme_error;

  /// No description provided for @rateApp.
  ///
  /// In de, this message translates to:
  /// **'Bewerten'**
  String get rateApp;

  /// No description provided for @scan_not_required.
  ///
  /// In de, this message translates to:
  /// **'Broadcast-Modus: Für diesen Hub ist kein Scan oder Koppeln nötig.'**
  String get scan_not_required;

  /// No description provided for @scan_running.
  ///
  /// In de, this message translates to:
  /// **'Suche läuft...'**
  String get scan_running;

  /// No description provided for @select_train.
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle eine Lok aus der Liste aus'**
  String get select_train;

  /// No description provided for @sendEmail.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get sendEmail;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @settings_bg_mode.
  ///
  /// In de, this message translates to:
  /// **'Hosentaschen-Modus'**
  String get settings_bg_mode;

  /// No description provided for @settings_bg_mode_desc.
  ///
  /// In de, this message translates to:
  /// **'Steuerung bleibt bei gesperrtem Bildschirm aktiv. Verhindert Verbindungsabbrüche. (Verbraucht etwas mehr Akku)'**
  String get settings_bg_mode_desc;

  /// No description provided for @stop.
  ///
  /// In de, this message translates to:
  /// **'NOTHALT'**
  String get stop;

  /// No description provided for @stop_all.
  ///
  /// In de, this message translates to:
  /// **'NOT-AUS'**
  String get stop_all;

  /// No description provided for @tab_general.
  ///
  /// In de, this message translates to:
  /// **'ALLGEMEIN'**
  String get tab_general;

  /// No description provided for @tab_scan.
  ///
  /// In de, this message translates to:
  /// **'SCAN'**
  String get tab_scan;

  /// No description provided for @tab_tuning.
  ///
  /// In de, this message translates to:
  /// **'FEINABSTIMMUNG'**
  String get tab_tuning;

  /// No description provided for @take_picture.
  ///
  /// In de, this message translates to:
  /// **'Foto aufnehmen'**
  String get take_picture;

  /// No description provided for @target.
  ///
  /// In de, this message translates to:
  /// **'SOLL'**
  String get target;

  /// No description provided for @template_circuit_cube.
  ///
  /// In de, this message translates to:
  /// **'Belegung:\n• Port A: Antrieb\n• Port B/C: Licht (fahrtabhängig)\nVerbindung: BLE-Scan.\n\nTipp:\nHalte die Lok in der Liste lange gedrückt, um die Einstellungen und diesen Infokasten zu bearbeiten'**
  String get template_circuit_cube;

  /// No description provided for @template_lego_duplo.
  ///
  /// In de, this message translates to:
  /// **'Duplo-Lok, ohne Ports.\n\nTipp:\nHalte die Lok in der Liste lange gedrückt, um die Einstellungen und diesen Infokasten zu bearbeiten'**
  String get template_lego_duplo;

  /// No description provided for @template_lego_hub.
  ///
  /// In de, this message translates to:
  /// **'Standard-Belegung:\n• Port A: Antrieb\n• Port B: Licht/Motor\nVerbindung: BLE-Scan.\n\nTipp:\nHalte die Lok in der Liste lange gedrückt, um die Einstellungen und diesen Infokasten zu bearbeiten'**
  String get template_lego_hub;

  /// No description provided for @template_mould_king.
  ///
  /// In de, this message translates to:
  /// **'Standard-Belegung:\n• Port A: Antrieb\n• Port B/C: Licht (fahrtabhängig)\n• Port D: evt. 2. Antrieb (invertiert)\nVerbindung: BLE-Scan.\n\nTipp:\nHalte die Lok in der Liste lange gedrückt, um die Einstellungen und diesen Infokasten zu bearbeiten'**
  String get template_mould_king;

  /// No description provided for @template_mould_king_classic.
  ///
  /// In de, this message translates to:
  /// **'Standard-Belegung:\n• Port A: Antrieb\n• Port B/C: Licht (fahrtabhängig)\n• Port D: evt. 2. Antrieb (invertiert)\nVerbindung: Broadcast-Modus.\n\nTipp:\nHalte die Lok in der Liste lange gedrückt, um die Einstellungen und diesen Infokasten zu bearbeiten'**
  String get template_mould_king_classic;

  /// No description provided for @template_mould_king_rwy_controller.
  ///
  /// In de, this message translates to:
  /// **'FUNKTIONIERT NOCH NICHT\nNur Motor, kein Licht'**
  String get template_mould_king_rwy_controller;

  /// No description provided for @template_pybricks_hub.
  ///
  /// In de, this message translates to:
  /// **'FUNKTIONIERT (NOCH) NICHT\nStandard-Belegung:\n• Port A: Antrieb\n• Port B: Licht/Motor\nVerbindung: BLE-Scan.\n\nTipp:\nHalte die Lok in der Liste lange gedrückt, um die Einstellungen und diesen Infokasten zu bearbeiten'**
  String get template_pybricks_hub;

  /// No description provided for @theme_dark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get theme_dark;

  /// No description provided for @theme_light.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get theme_light;

  /// No description provided for @theme_system.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get theme_system;

  /// No description provided for @tuning_acceleration.
  ///
  /// In de, this message translates to:
  /// **'Beschleunigung'**
  String get tuning_acceleration;

  /// No description provided for @tuning_auto_light.
  ///
  /// In de, this message translates to:
  /// **'Automatisches Licht'**
  String get tuning_auto_light;

  /// No description provided for @tuning_auto_light_help.
  ///
  /// In de, this message translates to:
  /// **'Aktiviert das fahrtrichtungsabhängige Umpolen an Port B für BicolorLEDs'**
  String get tuning_auto_light_help;

  /// No description provided for @tuning_brake.
  ///
  /// In de, this message translates to:
  /// **'Bremskraft'**
  String get tuning_brake;

  /// No description provided for @tuning_delta_step.
  ///
  /// In de, this message translates to:
  /// **'Stufensprung (+/- Tasten)'**
  String get tuning_delta_step;

  /// No description provided for @tuning_driving_behavior.
  ///
  /// In de, this message translates to:
  /// **'FAHRVERHALTEN'**
  String get tuning_driving_behavior;

  /// No description provided for @tuning_general_settings.
  ///
  /// In de, this message translates to:
  /// **'Allgemeine Einstellungen'**
  String get tuning_general_settings;

  /// No description provided for @tuning_hardware_title.
  ///
  /// In de, this message translates to:
  /// **'Hardware und Ports'**
  String get tuning_hardware_title;

  /// No description provided for @tuning_hardware_subtitle.
  ///
  /// In de, this message translates to:
  /// **'Weise jedem Anschluss der Akkubox eine Funktion zu.'**
  String get tuning_hardware_subtitle;

  /// No description provided for @tuning_hardware_label.
  ///
  /// In de, this message translates to:
  /// **'Beschriftung (z.B. Hupe)'**
  String get tuning_hardware_label;

  /// No description provided for @tuning_hardware_key.
  ///
  /// In de, this message translates to:
  /// **'Welche Taste?'**
  String get tuning_hardware_key;

  /// No description provided for @tuning_hardware_channel.
  ///
  /// In de, this message translates to:
  /// **'Welcher Kanal?'**
  String get tuning_hardware_channel;

  /// No description provided for @tuning_invert_direction.
  ///
  /// In de, this message translates to:
  /// **'Richtung invertieren'**
  String get tuning_invert_direction;

  /// No description provided for @tuning_invert_direction_help.
  ///
  /// In de, this message translates to:
  /// **'Kehrt die Standard-Laufrichtung des Motors in der App um'**
  String get tuning_invert_direction_help;

  /// No description provided for @tuning_limits.
  ///
  /// In de, this message translates to:
  /// **'Geschwindigkeitsgrenzen'**
  String get tuning_limits;

  /// No description provided for @tuning_pfx_title.
  ///
  /// In de, this message translates to:
  /// **'PFx-Action-Buttons'**
  String get tuning_pfx_title;

  /// No description provided for @tuning_pfx_subtitle.
  ///
  /// In de, this message translates to:
  /// **'Lege eigene Knöpfe für Sounds und Lichter auf Kanal 2, 3 oder 4 an.'**
  String get tuning_pfx_subtitle;

  /// No description provided for @tuning_profile_1.
  ///
  /// In de, this message translates to:
  /// **'PROFIL I (Solo-Fahrt)'**
  String get tuning_profile_1;

  /// No description provided for @tuning_profile_2.
  ///
  /// In de, this message translates to:
  /// **'PROFIL II (Fahrt unter Last)'**
  String get tuning_profile_2;

  /// No description provided for @tuning_ramp_delay.
  ///
  /// In de, this message translates to:
  /// **'Trägheit [ms]'**
  String get tuning_ramp_delay;

  /// No description provided for @tuning_ramping.
  ///
  /// In de, this message translates to:
  /// **'Beschleunigungs-Rampe'**
  String get tuning_ramping;

  /// No description provided for @tuning_reverse.
  ///
  /// In de, this message translates to:
  /// **'Rückwärts-Limit'**
  String get tuning_reverse;

  /// No description provided for @tuning_speed_levels.
  ///
  /// In de, this message translates to:
  /// **'FAHRSTUFEN'**
  String get tuning_speed_levels;

  /// No description provided for @ui_auto_scale.
  ///
  /// In de, this message translates to:
  /// **'Automatische Skalierung'**
  String get ui_auto_scale;

  /// No description provided for @ui_auto_scale_desc.
  ///
  /// In de, this message translates to:
  /// **'Passt die App-Größe automatisch an dein Display an.'**
  String get ui_auto_scale_desc;

  /// No description provided for @ui_scaling_manual.
  ///
  /// In de, this message translates to:
  /// **'Manuelle Skalierung'**
  String get ui_scaling_manual;

  /// No description provided for @unknown_device.
  ///
  /// In de, this message translates to:
  /// **'Unbekanntes Gerät'**
  String get unknown_device;

  /// No description provided for @unknown_protocol.
  ///
  /// In de, this message translates to:
  /// **'Unbekanntes Protokoll:'**
  String get unknown_protocol;

  /// No description provided for @vMax.
  ///
  /// In de, this message translates to:
  /// **'Vmax (Höchstgeschwindigkeit)'**
  String get vMax;

  /// No description provided for @vMin.
  ///
  /// In de, this message translates to:
  /// **'Vmin (Mindestgeschwindigkeit)'**
  String get vMin;

  /// No description provided for @workshop_add.
  ///
  /// In de, this message translates to:
  /// **'NEUE LOK ANLEGEN'**
  String get workshop_add;

  /// No description provided for @workshop_edit.
  ///
  /// In de, this message translates to:
  /// **'LOK EDITIEREN'**
  String get workshop_edit;

  /// No description provided for @workshop_edit_save.
  ///
  /// In de, this message translates to:
  /// **'SPEICHERN'**
  String get workshop_edit_save;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'da',
    'de',
    'en',
    'fr',
    'it',
    'nl',
    'pl',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'da':
      return AppLocalizationsDa();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
