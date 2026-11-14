# NoppenExpress Workspace-Regeln

Dieses Dokument definiert verbindliche Richtlinien für die Entwicklung und Unterstützung im Projekt **NoppenExpress**.

---

## 1. Sprache
* **Immer auf Deutsch antworten**: Sämtliche Antworten, Erläuterungen, Nachfragen und Zusammenfassungen müssen ausnahmslos auf Deutsch formuliert werden.

---

## 2. Code-Bestandsschutz (Methoden & Timer)
* **Niemals ungefragt löschen**: Bestehende Methoden, Funktionen, Callbacks oder `Timer` (z. B. `_centralRampingTimer`, Ramping-, Polling-, Watchdog- oder Reconnect-Timer) dürfen **niemals** eigenmächtig oder ohne vorherige ausdrückliche Erlaubnis des Nutzers gelöscht oder ersatzlos entfernt werden.
* **Erweiterung vor Löschung**: Bestehende Logik soll bei Anpassungen refaktoriert, erweitert oder abgesichert werden, anstatt funktionierenden Code zu verwerfen.

---

## 3. Architektur & TrainConfig-Vererbung
* **Zentrale `TrainConfig`-Vererbung**: Nutze immer die zentrale Daten- und Vererbungsstruktur rund um `TrainConfig` und `TrainController` (`lib/controllers/train_controller.dart`).
* **Controller-Ableitung**: Alle Hardware- und Zug-Controller (z. B. `CircuitCubeController`, `PFxBrickController` etc.) müssen von der Basisklasse `TrainController` erben und `TrainConfig` über den Konstruktor (`super(config)` bzw. `super.config`) übernehmen.
* **Keine Parallelstrukturen**: Konfigurationsparameter (z. B. Geschwindigkeitsstufen, Ramping, Ports, Bluetooth-MAC-Adressen, Profile) dürfen nicht unabhängig oder hartcodiert an `TrainConfig` vorbei verwaltet werden.
