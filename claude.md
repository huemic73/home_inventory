# CLAUDE.md – Entwickler-Richtlinien

Dieses Dokument enthält die wichtigsten Befehle und Entwicklungs-Richtlinien für das Projekt **Heiminventarisierung**.

## 🚀 Wichtige Befehle

### Entwicklung & Ausführung
* **App starten (Standardgerät):** `flutter run`
* **Web-App starten (Chrome):** `flutter run -d chrome --web-renderer html`
* **Abhängigkeiten laden:** `flutter pub get`

### Code-Qualität & Formatierung
* **Statische Analyse ausführen:** `dart analyze`
* **Automatische Formatierung:** `dart format .`
* **Automatische Fehlerbehebung:** `dart fix --apply`

### Build & Deployment
* **Android APK bauen:** `flutter build apk --release`
* **Web-Build generieren:** `flutter build web --release`
* **Docker Container starten:** `docker-compose up -d --build`

---

## 🛠 Architektur & Entwicklungs-Richtlinien

### 1. Datei- und Code-Struktur
* **[`lib/models.dart`](file:///C:/Users/micha/AndroidStudioProjects/home_inventory/lib/models.dart):** Enthält alle Datenmodelle (`StorageNode`, `Item`, `Tag`) und Hilsklassen zur Konvertierung aus PocketBase-Records.
* **[`lib/ui_components.dart`](file:///C:/Users/micha/AndroidStudioProjects/home_inventory/lib/ui_components.dart):** Zentrale UI-Komponenten (Karten, Dialoge, Netzwerkladebilder). Layouts MÜSSEN `InventoryPageLayout` für konsistente Header, Breadcrumbs und Hintergrund-Gradients verwenden.
* **[`lib/*_screen.dart`](file:///C:/Users/micha/AndroidStudioProjects/home_inventory/lib/):** Einzelne Screens für Navigation und Listen.

### 2. UI- & UX-Konventionen
* **Einheitliche Menüführung:** Verwende für Aktionen immer ein Drei-Punkte-Menü (`PopupMenuButton`), das kompakte `ListTile`s mit passenden Icons enthält.
* **Destruktive Aktionen:** Lösch-Optionen im Popup-Menü und Dialog-Buttons immer rot hervorheben (`color: Colors.red`).
* **Web-Kompatibilität:** Da Flutter Web auf SQLite/CachedNetworkImage verzichtet, bei Netzwerk-Bildern immer `kIsWeb`-Prüfungen integrieren und dort nativ `Image.network` nutzen (siehe `InventoryNetworkImage` in `lib/ui_components.dart`).
* **Mobile- & Web-Drag-and-Drop:** Bei Sortierlisten auf Web den direkten Ziehpunkt (`ReorderableDragStartListener`) aktivieren, auf Mobile den verzögerten Touch-Start (`ReorderableDelayedDragStartListener`) nutzen.

### 3. PocketBase Integration
* Immer `expand: 'tags'` für Abfragen nutzen, um verknüpfte Schlagworte direkt zu laden.
* Bei Änderungen an übergeordneten Knoten (z. B. Bearbeiten/Löschen des aktuellen Raums oder Containers) den State lokal updaten oder mit `Navigator.pop(context, true)` auf den Parent-Screen zurücknavigieren, um Datenverlust zu vermeiden.
