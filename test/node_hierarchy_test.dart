import 'package:flutter_test/flutter_test.dart';

enum NodeType {
  area,      // z.B. Erdgeschoss, Garten
  room,      // z.B. Küche, Werkstatt
  location,  // z.B. Regal, Schrank
  container  // z.B. Kiste, Tasche
}

class StorageNode {
  final String id;
  final String name;
  final NodeType type;
  StorageNode? parent;

  StorageNode({
    required this.id,
    required this.name,
    required this.type,
    this.parent,
  });

  /// Prüft, ob eine Node in eine andere gesteckt werden darf
  bool canBePlacedIn(StorageNode potentialParent) {
    // 1. Tiefer Zirkelbezug-Schutz (Rekursiv nach oben prüfen)
    StorageNode? currentInLineage = potentialParent;
    while (currentInLineage != null) {
      if (currentInLineage.id == id) return false; // Ich bin bereits ein Vorfahre meines neuen Vaters!
      currentInLineage = currentInLineage.parent;
    }
    
    // 2. Typschutz-Logik
    switch (type) {
      case NodeType.area:
        return false; // Ein Bereich ist immer Root (oder hat keinen Parent-Node)
      case NodeType.room:
        return potentialParent.type == NodeType.area;
      case NodeType.location:
        return potentialParent.type == NodeType.room || potentialParent.type == NodeType.area || potentialParent.type == NodeType.location;
      case NodeType.container:
        // Container dürfen in Orte, Räume oder andere Container ("Box-in-Box")
        return potentialParent.type == NodeType.location || 
               potentialParent.type == NodeType.room || 
               potentialParent.type == NodeType.container;
    }
  }

  /// Berechnet den vollständigen Pfad als Liste von Namen
  List<String> getBreadcrumbs() {
    List<String> path = [name];
    StorageNode? current = parent;
    while (current != null) {
      path.insert(0, current.name);
      current = current.parent;
    }
    return path;
  }
}

void main() {
  group('Node Hierarchie & Typschutz Tests', () {
    final areaEG = StorageNode(id: '1', name: 'Erdgeschoss', type: NodeType.area);
    final roomKueche = StorageNode(id: '2', name: 'Küche', type: NodeType.room);
    final locSchrank = StorageNode(id: '3', name: 'Vorratsschrank', type: NodeType.location);
    final locRegalbrett = StorageNode(id: '3b', name: 'Regalbrett 1', type: NodeType.location);
    final contBox = StorageNode(id: '4', name: 'Mehl-Box', type: NodeType.container);
    final contSubBox = StorageNode(id: '5', name: 'Kleine Dose', type: NodeType.container);

    test('Gültige Verschachtelungen', () {
      expect(roomKueche.canBePlacedIn(areaEG), isTrue, reason: 'Raum darf in Bereich');
      expect(locSchrank.canBePlacedIn(roomKueche), isTrue, reason: 'Ort darf in Raum');
      expect(locRegalbrett.canBePlacedIn(locSchrank), isTrue, reason: 'Ort darf in anderen Ort');
      expect(contBox.canBePlacedIn(locSchrank), isTrue, reason: 'Container darf in Ort');
      expect(contSubBox.canBePlacedIn(contBox), isTrue, reason: 'Container darf in Container (Box-in-Box)');
    });

    test('Ungültige Verschachtelungen (Typschutz)', () {
      expect(areaEG.canBePlacedIn(roomKueche), isFalse, reason: 'Bereich darf NICHT in Raum');
      expect(roomKueche.canBePlacedIn(contBox), isFalse, reason: 'Raum darf NICHT in Container');
      expect(locSchrank.canBePlacedIn(contBox), isFalse, reason: 'Ort darf NICHT in Container');
    });

    test('Zirkelbezug-Schutz Basis', () {
      expect(contBox.canBePlacedIn(contBox), isFalse, reason: 'Eine Node darf nicht ihr eigener Parent sein');
    });

    test('Tiefer Zirkelbezug-Schutz (A->B->C->A)', () {
      // Aufbau: Regal -> Box -> SubBox
      locSchrank.parent = roomKueche;
      contBox.parent = locSchrank;
      contSubBox.parent = contBox;

      // Versuch: Den Schrank in die SubBox stellen
      expect(locSchrank.canBePlacedIn(contSubBox), isFalse, 
        reason: 'Ein Vorfahre darf nicht in seinen eigenen Nachfahren verschoben werden');
    });

    test('Pfad-Berechnung (Breadcrumbs)', () {
      roomKueche.parent = areaEG;
      locSchrank.parent = roomKueche;
      contBox.parent = locSchrank;
      contSubBox.parent = contBox;

      expect(contSubBox.getBreadcrumbs(), 
        ['Erdgeschoss', 'Küche', 'Vorratsschrank', 'Mehl-Box', 'Kleine Dose']);
    });
  });
}
