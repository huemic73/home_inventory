# Heiminventarisierung (Home Inventory) v2.0

Eine moderne, rekursive Flutter-Anwendung zur Inventarverwaltung für zuhause. Organisiere deine Werkzeuge, Vorräte oder Sammlungen mit Fotos, QR-Codes und einer extrem flexiblen Struktur.

![Design](https://img.shields.io/badge/Design-Modern%20Blue-blue)
![Flutter](https://img.shields.io/badge/Framework-Flutter%203-02569B?logo=flutter)
![PocketBase](https://img.shields.io/badge/Backend-PocketBase-ADDEFF?logo=sqlite)

## 🚀 Features (v2.0)

- **Rekursive Hierarchie:** Schluss mit starren Ebenen! Organisiere dein Haus in beliebiger Tiefe: **Bereich** > **Raum** > **Regal** > **Reihe** > **Box** > **Kleine Kiste** > **Artikel**.
- **Flexibles Tagging & Beschreibungen:** Markiere sowohl **Gegenstände** als auch **Räume/Container** mit detaillierten Beschreibungen und frei definierbaren, farbigen Schlagworten (Tags).
- **Manuelle & automatische Sortierung:** Verschiebe Elemente per Drag-and-Drop (optimiert für Touch und Web) oder sortiere sie blitzschnell alphabetisch oder nach Erstellungsdatum. Die Reihenfolge wird permanent gespeichert.
- **Sticky UX & Dynamische Header:** Suchleisten und Tag-Filter passen ihre Höhe automatisch an und "kleben" beim Scrollen am oberen Rand.
- **Intelligentes QR-System:** 
  - Scanne Boxen oder Artikel, um sofort Details zu sehen.
  - **Einzelner QR-Code-Druck:** Drucke direkt aus der App QR-Code-Labels für Kisten, Räume oder Artikel (ideal für Etikettendrucker).
  - **Label-Recycling:** Weise bereits gedruckten Etiketten erst beim Bekleben neue Container zu.
- **Optimiertes Verschieben:** Verschiebe Boxen oder Artikel mit einer integrierten Echtzeit-Suche und Zirkelbezug-Schutz.
- **Profi-Suche:** Suche gleichzeitig nach Namen und mehreren Tags (AND-Verknüpfung).
- **Einheitliche & cleane App-Menüs:** Schlanke App-Bars und übersichtliche Drei-Punkte-Dropdown-Menüs (mit farbigen Icons) für eine intuitive Bedienung.
- **Visuelle Erfassung:** Unterstützung für Fotos auf jeder Ebene inklusive großer Header-Bilder und automatischer Kontrastanpassung.
- **Inventurhilfe:** Generiere strukturierte PDF-Listen aller Container inklusive QR-Codes.
- **Sicherheit:** Biometrischer Login (Fingerabdruck/FaceID) und persistente Sitzungen.

## 🛠 Tech-Stack & Architektur

- **Frontend:** Flutter (Material 3)
- **Backend:** [PocketBase](https://pocketbase.io)
- **Modell:** Einheitliches `StorageNode`-System für rekursive Verschachtelung.
- **Logik:** Rekursive Berechnung von Artikelbeständen über alle Unterebenen hinweg.
- **Component-based Design:** Alle zentralen UI-Elemente sind in `lib/ui_components.dart` zentralisiert.

---

## ⚙️ Setup & Installation

### 1. PocketBase Backend vorbereiten

1. Lade PocketBase von [pocketbase.io](https://pocketbase.io) herunter.
2. Starte den Server: `./pocketbase serve --http="0.0.0.0:8090"`.
3. Erstelle folgende Collections:

| Collection | Wichtige Felder | API Rules (Auth) |
| :--- | :--- | :--- |
| `nodes` | `name`, `type` (area,room,location,container), `parent` (Rel to nodes), `description`, `tags` (Rel to tags), `icon`, `photo`, `labelId` | `@request.auth.id != ""` |
| `items` | `name`, `quantity`, `node` (Rel to nodes), `tags` (Rel to tags), `photo` | `@request.auth.id != ""` |
| `tags` | `name`, `color` (Hex) | `@request.auth.id != ""` |

### 2. Flutter App konfigurieren

1. `flutter pub get`.
2. **Netzwerk:** In `lib/main.dart` die Variable `pcIp` auf die lokale IPv4-Adresse deines PCs setzen (für Android-Geräte).
3. **Build:** `flutter run` (minSdk 21).

## 🐳 Docker Deployment

Die Anwendung kann extrem einfach als Docker-Container betrieben werden. Dabei wird die Flutter-Web-App direkt von PocketBase mitserviert.

### 1. Container bauen und starten
Führe im Hauptverzeichnis des Projekts folgenden Befehl aus:

```bash
docker-compose up -d --build
```

Die App ist danach unter `http://<deine-server-ip>:8090` erreichbar.

### 2. Daten-Persistenz
Alle Daten (Datenbank, Bilder, Einstellungen) werden in einem Docker-Volume namens `pb_data` gespeichert und bleiben auch bei Container-Updates erhalten.

### 3. PocketBase Admin-Setup
Nach dem ersten Start musst du:
1. Unter `http://<deine-server-ip>:8090/_/` einen Admin-Account anlegen.
2. Die Collections (`nodes`, `items`, `tags`) erstellen, wie im Abschnitt "Setup & Installation" beschrieben.
