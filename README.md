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
- **Inventurhilfe:** Generiere strukturierte PDF-Listen aller Container, gruppiert nach Räumen und Orten, inklusive QR-Codes.
- **Benutzerverwaltung:** Sicherer Login-Bereich mit Profilverwaltung und Passwort-Änderung.
- **Theme-Support:** Volle Unterstützung für **Light Mode**, **Dark Mode** und Systemstandard (persistente Speicherung).
- **Modernes Design:** "Modern Blue" Theme (Indigo-Akzente) mit der Schriftart "Outfit" und vereinheitlichten UI-Komponenten.

## 🛠 Tech-Stack

- **Frontend:** Flutter (Material 3)
- **Backend:** [PocketBase](https://pocketbase.io) (Self-hosted Go/SQLite)
- **Schlüssel-Pakete:** 
  - `shared_preferences` (Theme-Speicherung)
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
3. **Netzwerk:** In `lib/main.dart` die Variable `pcIp` auf die lokale IPv4-Adresse deines PCs setzen.
4. **Build:** `flutter run` (erfordert minSdk 21).

---

## 🏗 Architektur-Hinweis
Die App nutzt ein **Component-based Design**. Zentrale UI-Elemente wie Buttons (`StandardFab`) und Eingabemasken (`InventoryForm`) sind in `lib/ui_components.dart` definiert, was für eine absolut konsistente Benutzeroberfläche und einfache Wartbarkeit sorgt.
