# Projekt-Kontext: Heiminventarisierung (Home Inventory)

Dieses Dokument dient als Wissensbasis für KI-Assistenten (wie Claude oder Gemini), um den aktuellen Stand und die Architektur dieses Projekts schnell zu erfassen.

## 📌 Projektziel
Entwicklung einer modernen, hierarchischen Inventarverwaltung für den privaten Gebrauch. Fokus liegt auf Schnelligkeit, visueller Orientierung (Fotos) und einem intelligenten QR-Code-System.

## 🛠 Tech-Stack
- **Frontend:** Flutter (Material 3)
- **Backend:** PocketBase (Go/SQLite)
- **Design:** "Modern Blue" Theme (Indigo #3F51B5), Google Font "Outfit", 32px Border Radius.
- **Plattformen:** Android (Pixel 9 Optimierung), Web (Docker-ready).

## 🗂 Daten-Hierarchie & Struktur
Die Daten sind in vier Ebenen organisiert:
1.  **Raum (`rooms`)**: Höchste Ebene (z.B. Garage, Keller).
2.  **Ablageort (`storage_locations`)**: Optionale Unterteilung (z.B. Regal A, Schrank 1). Gehört zu einem Raum.
3.  **Container (`containers`)**: Physische Boxen oder Fächer. Gehören zu einem Raum und optional zu einem Ablageort.
4.  **Artikel (`items`)**: Die eigentlichen Gegenstände in den Containern.

## 🔍 Besondere Logik & Features
- **QR-System:**
    - Codes folgen dem Format `home_inventory_container:ID`.
    - **Label-Recycling:** Boxen können eine manuelle `labelId` haben. Beim Scan wird erst nach dieser ID gesucht, dann nach der Datenbank-ID. Dies erlaubt das Vorab-Drucken von Stickern.
    - **Röntgenblick:** Das Scannen einer Box zeigt sofort deren Inhalt mit Fotos an.
- **Networking:** In `main.dart` wird dynamisch zwischen `127.0.0.1` (Web) und einer PC-IP (Android Handy) umgeschaltet.
- **Inventurhilfe:** PDF-Export aller Labels, gruppiert nach Räumen und Ablageorten für den physischen Abgleich.
- **Theme-Management:** Light, Dark und System-Modus via `shared_preferences` und `ValueNotifier`.
- **Auth:** Benutzerverwaltung via PocketBase (`users`-Collection) mit Passwort-Änderungsfunktion.

## 🏗 Wichtige Dateien
- `lib/models.dart`: Zentrale Datenmodelle und Icon-Mappings.
- `lib/main.dart`: App-Entry, Theme-Konfiguration, IP-Einstellung.
- `lib/room_list_screen.dart`: Dashboard mit "Ohne Zuordnung"-Zähler.
- `lib/container_list_screen.dart`: Raum-Detailansicht (Orte + Boxen).
- `lib/global_search_screen.dart`: Globale Suche mit Pfad-Anzeige.
- `lib/scanner_screen.dart`: QR-Logik mit Zuweisungsmodus.

## 🚦 Aktueller Status
- **Abgeschlossen:** Hierarchie-Umbau (Ablageorte), Dark Mode Optimierung, Globale Suche, PDF-Gruppierung, Login/Auth.
- **Bekannte Kniffe:** Beim Verschieben von Artikeln/Containern wird die Kette Raum -> Ort -> Box gefiltert, um Fehlleitungen zu vermeiden.
