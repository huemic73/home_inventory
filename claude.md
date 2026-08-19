# Projekt-Kontext: Heiminventarisierung (Home Inventory) v2.0

Dieses Dokument dient als Wissensbasis für KI-Assistenten, um den aktuellen Stand und die Architektur dieses Projekts schnell zu erfassen.

## 📌 Projektziel
Entwicklung einer modernen, rekursiven Inventarverwaltung. Fokus auf maximaler Flexibilität ("Box-in-Box"), Schnelligkeit und einem intelligenten Tagging-System.

## 🛠 Tech-Stack & Architektur
- **Frontend:** Flutter (Material 3)
- **Backend:** PocketBase (Go/SQLite)
- **Recursive Core:** Alle physischen Orte werden durch die Klasse `StorageNode` (`lib/models.dart`) repräsentiert. Unterscheidung erfolgt über `NodeType` (`area`, `room`, `location`, `container`).
- **Tagging Engine:** Artikel können beliebig viele farbige `Tags` besitzen.
- **Master-Layout:** Alle Seiten nutzen `InventoryPageLayout` (`lib/ui_components.dart`) mit dynamischer Header-Höhenberechnung und Sticky-Effekten.

## 🗂 Daten-Struktur (v2.0)
1.  **Nodes (`nodes`)**: Rekursive Tabelle. Jede Node hat optional einen `parent` (andere Node).
2.  **Items (`items`)**: Gehören zu einer Node und haben eine Liste von Tags.
3.  **Tags (`tags`)**: Globale Schlagworte mit Name und Farbe.

## 🔍 Besondere Logik
- **Recursive Counting:** Die App berechnet Bestände rekursiv über den gesamten Baum (`calculateRecursive` in `RoomListScreen` und `ContainerListScreen`). Memoization sorgt für O(n) Performance.
- **Advanced Moving:** Verschiebe-Bildschirme nutzen eine Echtzeit-Suche und validieren Zirkelbezüge.
- **Tag-Search:** Die globale Suche unterstützt AND-Verknüpfungen mehrerer Tags kombiniert mit Textsuche.
- **QR-System:** Zentrales URL-Format (`qrBaseUrl`). Erkennt Nodes (`c/`) und Items (`i/`). Unterstützt manuelle `labelId`.
- **Biometrie:** `MainActivity` erbt von `FlutterFragmentActivity`. Start-Check via `AuthCheck`.

## 🏗 Struktur & Dateien
- `lib/ui_components.dart`: Master-Layout, dynamische Header, `InventoryForm` mit Tag-Selector.
- `lib/models.dart`: Zentrales Datenmodell, Icon-Mapping, Typschutz-Regeln.
- `lib/move_container_screen.dart` & `lib/move_item_screen.dart`: Optimierte Verschiebe-Logik mit Suche.
- `lib/global_search_screen.dart`: Multi-Tag-Filterung.

## 🚦 Aktueller Status
- **Status:** v2.0 produktiv. Hierarchie-Migration abgeschlossen.
- **Highlights:** Unbegrenzte Verschachtelungstiefe, Typschutz (z.B. kein Raum in eine Box), Multi-Tag-Suche, biometrische Sicherheit.
- **Wartbarkeit:** Alle UI-Komponenten sind in `ui_components.dart` zentralisiert. Die Datenabfragen sind auf rekursive Strukturen optimiert.
- **Roadmap:** Die Punkte "Rekursive Hierarchie" und "Tagging" aus der ursprünglichen `ROADMAP.md` wurden erfolgreich implementiert.
