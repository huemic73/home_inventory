# Projekt-Kontext: Heiminventarisierung (Home Inventory)

Dieses Dokument dient als Wissensbasis für KI-Assistenten, um den aktuellen Stand und die Architektur dieses Projekts schnell zu erfassen.

## 📌 Projektziel
Entwicklung einer modernen, hierarchischen Inventarverwaltung. Fokus auf Schnelligkeit, visueller Orientierung und einem flexiblen QR-Label-System.

## 🛠 Tech-Stack & Architektur
- **Frontend:** Flutter (Material 3)
- **Backend:** PocketBase (Go/SQLite)
- **Master-Layout:** Alle Übersichtsseiten nutzen die `InventoryPageLayout`-Komponente (`lib/ui_components.dart`), was einheitliche Header, Gradients und Sticky-Effekte garantiert.
- **Persistence:** `shared_preferences` für Einstellungen und Sitzungsdaten via `SharedPreferencesAuthStore`.
- **Sicherheit:** Integration von `local_auth` für biometrische Anmeldung. Die `MainActivity` erbt von `FlutterFragmentActivity`.
- **Data Access:** Konsequente Nutzung von `.get<T>("expand...")` für robuste Typisierung.

## 🗂 Daten-Hierarchie
1.  **Raum (`rooms`)**
2.  **Ablageort (`storage_locations`)**: Optional (Regal, Schrank). Gehört zu Raum.
3.  **Container (`containers`)**: Gehört zu Raum und optional zu Ablageort.
4.  **Artikel (`items`)**: Gehört zu Container.

## 🔍 Besondere Logik
- **Sticky-Zone:** Suchleisten und Filter nutzen `SliverPersistentHeader`, um beim Scrollen oben anzudocken.
- **QR-System:** Suche nach manueller `labelId` vor DB-ID. Scannen zeigt sofort Container-Inhalt ("Röntgenblick").
- **Biometrie-Workflow:** Automatischer Check beim Start via `AuthCheck`. Manueller Fallback-Button auf Sperrbildschirm bei Abbruch. Integration im Login-Screen für schnellen Re-Login.
- **Platform-Ready:** Die UI-Zentralisierung ist für **Platform-Adaptive Design** vorbereitet (einfaches Umschalten auf Cupertino/iOS-Stil in `ui_components.dart`).
- **Forms:** Einheitliche `InventoryForm` Komponente für alle Datentypen mit Kamera/Galerie-Support.

## 🏗 Struktur & Dateien
- `lib/ui_components.dart`: Master-Layout, Standard-Buttons und Formulare.
- `lib/models.dart`: Unified Models und Icon-Mapping.
- `lib/main.dart`: Theme-Logik, Auth-Check und App-Entry.
- `lib/global_search_screen.dart`: Globale Suche mit Deep-Linking zur Detailansicht.

## 🚦 Aktueller Status
- **Status:** Funktionsfähig & Hochgradig optimiert.
- **Vision:** Eine Roadmap für zukünftige Architektur-Änderungen (Rekursion, Bestandsführung) wurde in `ROADMAP.md` hinterlegt. Sobald Teile davon umgesetzt werden, muss die Datei entsprechend aktualisiert (Punkte entfernt oder als erledigt markiert) werden.
- **Highlights:** Biometrischer Login, persistente Sitzungen, vollautomatischer Dark-Mode-Support, einheitliche Layouts über alle Screens hinweg.
- **Wartbarkeit:** Alle UI-Schrauben sind in `ui_components.dart` zentralisiert. Die gesamte App folgt dem Material 3 Design-Standard (inklusive neuester Container-Farbnamen wie `surfaceContainerHighest`).
