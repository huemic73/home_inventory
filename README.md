# Heiminventarisierung (Home Inventory)

Eine moderne, hierarchische Flutter-Anwendung zur Inventarverwaltung für zuhause. Organisiere deine Werkzeuge, Vorräte oder Sammlungen mit Fotos, QR-Codes und einer klaren Struktur.

![Design](https://img.shields.io/badge/Design-Modern%20Blue-blue)
![Flutter](https://img.shields.io/badge/Framework-Flutter%203-02569B?logo=flutter)
![PocketBase](https://img.shields.io/badge/Backend-PocketBase-ADDEFF?logo=sqlite)

## 🚀 Features

- **Vierstufige Hierarchie:** Organisiere alles nach **Raum** > **Ablageort** (Regal/Schrank) > **Container** (Box) > **Artikel**.
- **Sticky UX:** Suchleisten und Filter "kleben" beim Scrollen am oberen Rand, um die Kontrolle jederzeit griffbereit zu halten.
- **Intelligentes QR-System:** 
  - Scanne Boxen, um sofort den Inhalt zu sehen ("digitales Fenster").
  - **Label-Recycling:** Weise bereits gedruckten Etiketten erst beim Bekleben neue Container zu.
- **Visuelle Erfassung:** Unterstützung für Fotos auf jeder Ebene (Ablageort, Container, Artikel) inklusive großer Header-Bilder.
- **Globale Suche:** Blitzschnelle Suche über das gesamte Inventar mit vollständiger Pfadanzeige.
- **Inventurhilfe:** Generiere strukturierte PDF-Listen aller Container, gruppiert nach Standorten, inklusive QR-Codes.
- **Benutzerverwaltung:** Sicherer Login-Bereich mit Profilverwaltung und Passwort-Änderung.
- **Theme-Support:** Volle Unterstützung für **Light Mode**, **Dark Mode** und Systemstandard (persistente Speicherung).

## 🛠 Tech-Stack & Architektur

- **Frontend:** Flutter (Material 3)
- **Backend:** [PocketBase](https://pocketbase.io)
- **Design-System:** "Modern Blue" Theme mit der Schriftart "Outfit".
- **Component-based Design:** Alle zentralen UI-Elemente (`StandardFab`, `InventoryForm`, `InventoryPageLayout`) sind in `lib/ui_components.dart` zentralisiert. Dies sorgt für eine absolut konsistente Benutzeroberfläche und ermöglicht blitzschnelle Design-Anpassungen (z.B. für iOS).

---

## ⚙️ Setup & Installation

### 1. PocketBase Backend vorbereiten

1. Lade PocketBase von [pocketbase.io](https://pocketbase.io) herunter.
2. Starte den Server: `./pocketbase serve --http="0.0.0.0:8090"`.
3. Erstelle folgende Collections:

| Collection | Felder | API Rules (Auth) |
| :--- | :--- | :--- |
| `rooms` | `name`, `icon` | `@request.auth.id != ""` |
| `storage_locations` | `name`, `room` (Rel), `icon`, `photo` (File) | `@request.auth.id != ""` |
| `containers` | `name`, `room` (Rel), `storage_location` (Rel), `icon`, `labelId`, `photo` | `@request.auth.id != ""` |
| `items` | `name`, `quantity`, `photo`, `container` (Rel) | `@request.auth.id != ""` |

### 2. Flutter App konfigurieren

1. `flutter pub get`.
2. **Netzwerk:** In `lib/main.dart` die Variable `pcIp` auf die lokale IPv4-Adresse deines PCs setzen (für Android-Devices).
3. **Build:** `flutter run` (minSdk 21).

---

## 🐳 Docker Deployment
Die Anwendung ist darauf ausgelegt, als Docker-Container zu laufen. Die Flutter-Web-App kann direkt im `pb_public` Ordner von PocketBase mitserviert werden.
