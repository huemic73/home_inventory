# Heiminventarisierung (Home Inventory)

Eine moderne, hierarchische Flutter-Anwendung zur Inventarverwaltung für zuhause. Organisiere deine Werkzeuge, Vorräte oder Sammlungen mit Fotos, QR-Codes und einer klaren Struktur.

![Design](https://img.shields.io/badge/Design-Modern%20Blue-blue)
![Flutter](https://img.shields.io/badge/Framework-Flutter%203-02569B?logo=flutter)
![PocketBase](https://img.shields.io/badge/Backend-PocketBase-ADDEFF?logo=sqlite)

## 🚀 Features

- **Vierstufige Hierarchie:** Organisiere alles nach **Raum** > **Ablageort** (Regal/Schrank) > **Container** (Box) > **Artikel**.
- **Intelligentes QR-System:** 
  - Scanne Boxen, um sofort den Inhalt zu sehen ("digitales Fenster").
  - **Label-Recycling:** Weise bereits gedruckten Etiketten erst beim Bekleben neue Container zu.
- **Visuelle Erfassung:** Unterstützung für Fotos auf jeder Ebene (Ablageort, Container, Artikel) via Kamera oder Galerie.
- **Globale Suche:** Blitzschnelle Suche über das gesamte Inventar mit Pfadanzeige (z.B. *Keller > Regal A > Blaue Box*).
- **Inventurhilfe:** Generiere strukturierte PDF-Listen aller Container, gruppiert nach Räumen, inklusive QR-Codes zum Abhaken.
- **Benutzerverwaltung:** Sicherer Login-Bereich mit Profilverwaltung und Passwort-Änderung.
- **Modernes Design:** "Modern Blue" Theme basierend auf Material 3 mit der Schriftart "Outfit".

## 🛠 Tech-Stack

- **Frontend:** Flutter (Material 3)
- **Backend:** [PocketBase](https://pocketbase.io) (Self-hosted Go/SQLite)
- **Schlüssel-Pakete:** 
  - `mobile_scanner` (QR-Erkennung)
  - `printing` & `pdf` (Label-Generierung)
  - `image_picker` (Foto-Management)
  - `google_fonts` (Outfit Font)

---

## ⚙️ Setup & Installation

### 1. PocketBase Backend vorbereiten

1. Lade PocketBase von [pocketbase.io](https://pocketbase.io) herunter.
2. Starte den Server:
   ```bash
   ./pocketbase serve --http="0.0.0.0:8090"
   ```
3. Erstelle einen Admin-Account unter `http://127.0.0.1:8090/_/`.
4. Erstelle folgende Collections mit den entsprechenden Feldern:

| Collection | Felder | API Rules (Auth) |
| :--- | :--- | :--- |
| `rooms` | `name` (Text), `icon` (Text) | `@request.auth.id != ""` |
| `storage_locations` | `name` (Text), `room` (Rel), `icon` (Text), `photo` (File) | `@request.auth.id != ""` |
| `containers` | `name` (Text), `room` (Rel), `storage_location` (Rel, opt), `icon` (Text), `labelId` (Text, unique), `photo` (File) | `@request.auth.id != ""` |
| `items` | `name` (Text), `quantity` (Number), `photo` (File), `container` (Rel, opt) | `@request.auth.id != ""` |

### 2. Flutter App konfigurieren

1. Klone das Repository.
2. Installiere die Abhängigkeiten: `flutter pub get`.
3. **Netzwerk:** Für die Nutzung auf echten Android-Geräten (z.B. Pixel 9) muss in `lib/main.dart` die Variable `pcIp` auf die aktuelle lokale IPv4-Adresse deines PCs gesetzt werden (via `ipconfig`).
4. **Build:**
   - Web: `flutter run -d chrome`
   - Android: `flutter run` (erfordert minSdk 21)

---

## 📖 Bedienung

1. **Struktur aufbauen:** Lege Räume an, füge bei Bedarf Ablageorte (Regale) hinzu und erstelle darin Container.
2. **QR-Labels:** Nutze die Funktion "Etiketten drucken" im Seitenmenü, um eine Inventurliste oder Aufkleber zu generieren.
3. **Zuweisung:** Klebe einen QR-Code auf eine neue Box, wähle in der App "Zuweisen" und scanne den Code – die Box ist nun digital verknüpft.
4. **Suchen & Finden:** Nutze die Lupe auf der Startseite, um Gegenstände sofort zu lokalisieren.

---

## 🐳 Docker Deployment (Geplant)
Die Anwendung ist darauf ausgelegt, als Docker-Container zu laufen. Die Flutter-Web-App kann direkt im `pb_public` Ordner von PocketBase mitserviert werden, um Datenbank und Frontend in einem einzigen Container zu vereinen.
