# NoppenExpress (BLE) 🚂💨
**Bedienungsanleitung / Manual** *(c) 2026 graefemeister@gmail.com*
![](assets/NoppenExpress_small.png)
---

## 🇩🇪 DEUTSCH
### Willkommen bei NoppenExpress!
Deine neue, smarte Schaltzentrale für Bluetooth-gesteuerte Klemmbaustein-Züge. Egal ob Rangierfahrt oder High-Speed, mit NoppenExpress hast du die volle Kontrolle.

![App-Vorschau](Screenshots/Screenshot_20260328-191326.png)

### 🛠 DIE WERKSTATT (Loks anlegen)
Nutze das **'+' Symbol**, um eine neue Lok anzulegen:
* **Bluetooth Scan:** Findet die MAC-Adresse deines Hubs (Mould King 6.0, LEGO® Hub, Circuit Cube oder andere) automatisch.
* **Personalisierung:** Gib der Lok einen Namen, lade ein eigenes Foto hoch und hinterlege Wartungs-Notizen.
* **Tuning:** Passe die 4 Fahrstufen (V1-V4) an, setze ein Limit für Rückwärtsfahrten oder konfiguriere das Ramping für besonders weiches Anfahren und Bremsen.


Besonderheit der MK-M6.0 Broadcast-Hubs

* Kein klassisches Bluetooth-Pairing: Im Gegensatz zu den regulären Mould King Hubs (die eine feste Bluetooth-Verbindung über ihre MAC-Adresse aufbauen), empfangen die MK-M6.0 Hubs (genau wie das RYW-Modul) ihre Steuerbefehle über ein Broadcast-Signal.
* Keine MAC-Adresse erforderlich: In der App wird keine MAC-Adresse hinterlegt. Die Zuordnung erfolgt ausschließlich über Funkkanäle (1 bis 3).

Anleitung: MK-M6.0 Broadcast-Hubs koppeln

1. Lokeinstellungen in der App
* Kanal zuweisen: Lege in den Lokeinstellungen der App den gewünschten Empfangskanal (1, 2 oder 3) für die Lok fest. Das Feld für die MAC-Adresse bleibt frei bzw. entfällt.

2. Hubs einschalten & synchronisieren
* Alle Hubs starten: Schalte alle MK-M6.0 Hubs ein, bis diese blinken.
* Erste Lok verbinden: Drücke in der App bei einer Lok auf „Verbinden“.
* Synchronisation prüfen: Sobald diese Verbindung aktiv ist, gleichen alle eingeschalteten Hubs ihren Blinktakt an und blinken synchron.
* Weitere Loks verbinden: Drücke nun in der App nacheinander bei allen übrigen Loks auf „Verbinden“.

3. Kanal direkt am Hub wählen
* Kanal durchschalten: Drücke die grüne Taste am MK-M6.0 Hub, um den Empfangskanal zu wechseln.
* Blink-Code abgleichen: Passe den Kanal am Hub an die Einstellung in der App an:
	* 1x Blinken = Kanal 1
	* 2x Blinken = Kanal 2
	* 3x Blinken = Kanal 3

![App-Vorschau](Screenshots/Screenshot_20260410-001104.png)

### 🕹 DAS STEUERPULT
Wähle eine Lok aus der seitlichen Liste, um sie zu verbinden:
* **Fahrstufen:** Nutze V1-V4 (Vorwärts) und R1-R4 (Rückwärts).
* **Ramping (Halt):** Die orangefarbene Taste bremst deine Lok sanft und realistisch bis zum Stillstand ab.
* **Zubehör:** Schalte die Lichter (Port B/C) bequem um.
* **Invertieren:** Fährt die Lok in die falsche Richtung? "Richtung Invertieren" löst das Problem sofort.

### ⚠️ SICHERHEIT GEHT VOR
* **Lok-Stopp:** Der rote Button im Steuerpult stoppt die aktuell gewählte Lok **SOFORT** (ohne Bremsverzögerung).
* **Global Stop:** Der große rote Button oben in der Menüleiste sendet einen Nothalt an **ALLE** aktuell verbundenen Loks.

### ⚙️ EINSTELLUNGEN & BACKUP
Im Dreipunkte-Menü findest du nützliche Extras:
* **Backup:** Exportiere all deine Loks als JSON-Datei, um sie auf einem anderen Gerät wieder zu importieren.
* **Darstellung:** Aktiviere den Darkmode oder skaliere die Buttons größer.
* **Wakelock:** Verhindert, dass dein Display während der Fahrt unerwünscht ausgeht.

---

## 🇺🇸 ENGLISH
### Welcome to NoppenExpress!
Your new, smart command center for Bluetooth-controlled brick trains. Whether shunting or running express, NoppenExpress gives you total control over your layout.

### 🛠 THE WORKSHOP (Adding Trains)
Tap the **'+' icon** to add a new train to your roster:
* **Bluetooth Scan:** Automatically finds the MAC address of your hub (Mould King, LEGO® Hub, Circuit Cube or others).
* **Personalization:** Give your train a name, upload a custom photo, and save maintenance notes.
* **Tuning:** Customize the speeds for the 4 gears (V1-V4), set a reverse limit, or configure the ramping steps for buttery-smooth acceleration.

* 
Special Feature of the MK-M6.0 Broadcast Hubs

* No Classic Bluetooth Pairing: Unlike standard Mould King hubs (which establish a direct Bluetooth connection via their MAC address), the MK-M6.0 hubs (just like the RYW module) receive their control commands via a connectionless broadcast signal.
* No MAC Address Required: No MAC address is entered or assigned in the app. Assignment is handled exclusively via radio channels (1 to 3).

Guide: Pairing MK-M6.0 Broadcast Hubs
1. Locomotive Settings in the App
* Assign Channel: Select the desired receiving channel (1, 2, or 3) for the locomotive in the app's locomotive settings. The MAC address field is not needed and remains blank.

2. Power On & Synchronize Hubs
* Turn On All Hubs: Switch on all MK-M6.0 hubs until they begin blinking.
* Connect First Locomotive: Tap "Connect" for one locomotive in the app.
* Verify Synchronization: Once this connection is active, all powered-on hubs will match their blinking rhythm and blink in sync.
* Connect Remaining Locomotives: Now tap "Connect" for all remaining locomotives in the app one by one.

3. Select Channel Directly on the Hub
* Cycle Through Channels: Press the green button on the MK-M6.0 hub to switch the receiving channel.
* Match Blink Code: Match the channel on the hub to the setting chosen in the app:
	* 1x Blink = Channel 1
	* 2x Blinks = Channel 2
	* 3x Blinks = Channel 3


### 🕹 THE CONTROL PANEL
Select a train from the sidebar to connect:
* **Gears:** Use buttons V1-V4 (Forward) and R1-R4 (Reverse).
* **Ramping (Halt):** The orange button slows your train down gently and realistically until it stops.
* **Accessories:** Toggle the lights (Ports B and C).
* **Invert:** A quick tap on "Invert Direction" solves orientation issues instantly.

### ⚠️ SAFETY FIRST
* **Train Stop:** The red button on the control panel stops the currently selected train **IMMEDIATELY**.
* **Global Stop:** The large red button in the top menu bar instantly sends an emergency stop signal to **ALL** currently connected trains.

### ⚙️ SETTINGS & BACKUP
You will find useful extras in the three-dot menu:
* **Backup:** Export all your trains to a JSON file to import them onto another device.
* **Appearance:** Activate Dark Mode or scale up the UI buttons.
* **Wakelock:** Prevents your screen from turning off unexpectedly while driving.
