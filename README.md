# Heiminventarisierung

Eine moderne Flutter-Anwendung zur hierarchischen Inventarverwaltung für zuhause, unterstützt durch ein PocketBase-Backend.

## Features

- **Hierarchische Struktur:** Organisiere Gegenstände in Räumen und Containern (Boxen, Regale, etc.).
- **Foto-Upload:** Erfasse Gegenstände visuell mit der Kamera oder Galerie (funktioniert auch im Web-Browser).
- **Globale Suche:** Finde Artikel schnell über alle Räume und Container hinweg.
- **Verschieben-Funktion:** Ordne Gegenstände jederzeit neu zu oder verschiebe sie zwischen Containern.
- **CRUD-Operationen:** Räume, Container und Artikel können erstellt, bearbeitet und gelöscht werden.

## Tech-Stack

- **Frontend:** [Flutter](https://flutter.dev) (Material 3)
- **Backend:** [PocketBase](https://pocketbase.io)
- **Pakete:** `pocketbase`, `image_picker`, `cached_network_image`, `http`.

---

## Setup & Installation

### 1. PocketBase Backend vorbereiten

1. Lade PocketBase von [pocketbase.io](https://pocketbase.io) herunter.
2. Starte den Server in einem Terminal:
   ```bash
   ./pocketbase serve --http="0.0.0.0:8090"
   ```
3. Erstelle einen Superuser unter `http://127.0.0.1:8090/_/`.
4. Erstelle folgende Collections:

#### Collection: `rooms`
- Fields: `name` (Text, required)
- API Rules: Alle leer lassen (öffentlich).

#### Collection: `containers`
- Fields:
  - `name` (Text, required)
  - `room` (Relation, Max Select: 1, Collection: `rooms`, Required: Ja)
- API Rules: Alle leer lassen.

#### Collection: `items`
- Fields:
  - `name` (Text, required)
  - `quantity` (Number, Non-negative: Ja)
  - `photo` (File, Max Select: 1, Mime types: images)
  - `container` (Relation, Max Select: 1, Collection: `containers`, Required: Nein)
- API Rules: Alle leer lassen.

### 2. Flutter App starten

1. Klone das Repository oder öffne den Projektordner in Android Studio.
2. Stelle sicher, dass die Abhängigkeiten installiert sind:
   ```bash
   flutter pub get
   ```
3. **Netzwerk-Konfiguration:**
   - Die App nutzt automatisch `10.0.2.2` für den Android-Emulator und `127.0.0.1` für Web/Desktop.
   - Falls du ein echtes Android-Gerät nutzt, passe die `baseUrl` in `lib/main.dart` an deine lokale PC-IP an.
4. Starte die App:
   - Für Web: `flutter run -d chrome`
   - Für Android: Wähle deinen Emulator/Handy und klicke auf "Run".

---

## Benutzung

1. **Räume anlegen:** Erstelle zuerst Räume (z.B. Keller, Garage).
2. **Container hinzufügen:** Navigiere in einen Raum und erstelle dort Container (z.B. Regal A, Box 1).
3. **Gegenstände erfassen:** In den Containern kannst du nun Artikel mit Foto und Menge hinzufügen.
4. **Aufräumen:** Nutze die Liste "Ohne Zuordnung" auf dem Startbildschirm, um Artikel zu finden, die noch in keiner Box liegen.
