# Zukunfts-Roadmap: Heiminventarisierung

Dieses Dokument hält Visionen und geplante Architektur-Änderungen für die Version 2.0 der Anwendung fest. Es dient als Leitfaden für zukünftige Erweiterungen.

## 1. Rekursive Hierarchie ("Alles ist ein Container")
Aktuell nutzt die App eine starre Struktur: `Raum > Ort > Container > Artikel`. Ziel ist die Umstellung auf ein rekursives **Composite Pattern**.

### Konzept
- **Einheitliches Modell:** `StorageNode` (ersetzt `StorageLocation` und `InventoryContainer`).
- **Rekursion:** Jede `StorageNode` kann einen `Parent` haben (entweder ein `Room` oder eine andere `StorageNode`).
- **Attribut `isFixed`:** Unterscheidung zwischen fest verbauten Orten (Regal, Schrank) und mobilen Einheiten (Box, Kiste) für UI-Icons.

### Vorteile
- Beliebig tiefe Verschachtelung (z. B. *Schrank > Fach > Werkzeugkoffer > Sortierbox > Schrauben*).
- Vereinfachte Codebasis durch einheitliche Screens für Inhaltsanzeige.
- Massives Verschieben: Wird ein Regal verschoben, wandern alle enthaltenen Boxen automatisch mit.

---

## 2. Intelligente Bestandsführung (Splitting & Consumption)
Aktuell werden Artikel als unteilbare Einheiten behandelt. Ziel ist eine dynamische Mengenverwaltung.

### Teilmengen verschieben (Splitting)
- Beim Verschieben eines Artikels mit Menge > 1 wird gefragt: "Wie viele Einheiten?"
- Falls Menge < Gesamt: Reduzierung am Quellort, Neuanlage (Kopie) am Zielort.

### Stammdaten-Trennung (Optional)
- Umstellung auf zwei Tabellen: `Products` (Was ist es? Name, Foto) und `Stock` (Wo liegt es? Produkt-ID, Container-ID, Menge).
- Ermöglicht globale Bestandsabfragen: "Wie viele Batterien habe ich insgesamt im Haus?"

---

## 3. Tagging & Kategorisierung (Umgesetzt)
Zusätzlich zur physischen Hierarchie können Artikel nun mit Tags versehen werden.

### Features
- **Farbig markierte Tags:** Jeder Tag kann eine eigene Farbe haben.
- **Suche nach Tags:** Die globale Suche findet Artikel nun auch über ihre Schlagworte.
- **Mehrfach-Zuweisung:** Ein Artikel kann beliebig viele Tags haben (z.B. "Camping" und "Werkzeug").

---

## 4. UX & Interaktion
- **Breadcrumbs:** Navigationspfad oben in der Leiste, um bei tiefen Verschachtelungen die Orientierung zu behalten.
- **Schnellentnahme:** Ein-Klick-Buttons in der Artikelliste, um Bestände sofort zu reduzieren (Verbrauchsmaterial).
- **QR-Ketten:** Scannen eines Regals zeigt sofort die Liste aller darin enthaltenen Boxen ("Digitales Fenster").

---

## 4. Technische Vorbereitung
- **Zentrale QR-Domain:** Bereits implementiert (`qrBaseUrl` in `models.dart`). Ermöglicht späteren Wechsel auf lokale Docker-IPs/Domains ohne Code-Anpassung.
- **Deep-Linking:** Wiederaufnahme der `app_links` Integration, sobald eine stabile Domain/IP (z.B. via Docker) feststeht.
