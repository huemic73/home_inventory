# Projekt-Kontext: Heiminventarisierung (Home Inventory)

Dieses Dokument dient als Wissensbasis für KI-Assistenten, um den aktuellen Stand und die Architektur dieses Projekts schnell zu erfassen.

## 📌 Projektziel
Entwicklung einer modernen, hierarchischen Inventarverwaltung. Fokus auf Schnelligkeit, visueller Orientierung (Fotos auf allen Ebenen) und einem flexiblen QR-Label-System.

## 🛠 Tech-Stack & Architektur
- **Frontend:** Flutter (Material 3)
- **Backend:** PocketBase (Go/SQLite)
- **Komponenten-Architektur:** Zentrale Steuerung von UI-Elementen über `lib/ui_components.dart` (z.B. `StandardFab`, `InventoryForm`).
- **Persistence:** `shared_preferences` für lokale Einstellungen (z.B. ThemeMode).
- **Modernized Data Access:** Konsequente Nutzung der stabilen `.get<T>("expand...")` Syntax für PocketBase Records.

## 🗂 Daten-Hierarchie
1.  **Raum (`rooms`)**
2.  **Ablageort (`storage_locations`)**: Optional (z.B. Regal, Schrank). Gehört zu Raum.
3.  **Container (`containers`)**: Gehört zu Raum und optional zu Ablageort.
4.  **Artikel (`items`)**: Gehört zu Container.

## 🔍 Besondere Logik
- **QR-System:** Erst-Suche nach manueller `labelId` (Recycling), dann Fallback auf DB-ID. Scannen einer Box fungiert als "digitales Fenster" zum Inhalt.
- **Theme:** Dynamische Umschaltung (Light/Dark/System) im Benutzerprofil.
- **Forms:** Alle Eingaben laufen über eine vereinheitlichte `InventoryForm` Komponente mit Bild-Support (Kamera/Galerie).
- **Networking:** Automatisches Umschalten zwischen Localhost (Web) und PC-IP (Android Device).

## 🏗 Struktur & Dateien
- `lib/ui_components.dart`: Basis aller Buttons und Formulare.
- `lib/models.dart`: Unified Models und Icon-Mapping.
- `lib/main.dart`: Theme-Logik und App-Entry.
- `lib/global_search_screen.dart`: Suche mit Echtzeit-Pfad-Update nach Verschiebe-Aktionen.

## 🚦 Aktueller Status
- **Status:** Funktionsfähig & Optimiert.
- **Highlights:** Vollständiger Dark-Mode-Support, einheitliche Formular-Layouts für Desktop/Mobile, robuste Fehlerbehandlung bei Netzwerk-Wechseln.
- **Clean Code:** Unbenutzte Imports entfernt, asynchrone Context-Aufrufe (`await`) stabilisiert, Deprecated-Funktionen ersetzt.
