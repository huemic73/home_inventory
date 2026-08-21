import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_inventory/models.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('Real Models & Mapping Tests', () {
    test('Tag hex-color parsing to flutter Color', () {
      final record = RecordModel({
        'id': 'tag1',
        'name': 'Werkzeug',
        'color': '#FF5733',
      });
      final tag = Tag.fromRecord(record);

      expect(tag.id, 'tag1');
      expect(tag.name, 'Werkzeug');
      expect(tag.color, '#FF5733');
      expect(tag.colorData, const Color(0xFFFF5733));
    });

    test('Tag invalid hex-color fallback to grey', () {
      final record = RecordModel({
        'id': 'tag2',
        'name': 'Invalid Color Tag',
        'color': 'xyz',
      });
      final tag = Tag.fromRecord(record);
      expect(tag.colorData, Colors.grey);
    });

    test('StorageNode mapping and icon fallbacks', () {
      final record = RecordModel({
        'id': 'node1',
        'name': 'Gartenhaus',
        'type': 'bereich',
        'icon': 'garage',
        'photo': 'pic.jpg',
        'labelId': 'lbl123',
        'parent': '',
      });
      final node = StorageNode.fromRecord(record);

      expect(node.id, 'node1');
      expect(node.name, 'Gartenhaus');
      expect(node.type, NodeType.bereich);
      expect(node.photo, 'pic.jpg');
      expect(node.labelId, 'lbl123');
      expect(node.parentId, '');
      expect(node.icon, Icons.garage); // uses mapped icon
    });

    test('StorageNode canBePlacedIn constraints', () {
      final recordBereich = RecordModel({
        'id': 'b1',
        'name': 'Bereich',
        'type': 'bereich',
      });
      final recordRaum = RecordModel({
        'id': 'r1',
        'name': 'Raum',
        'type': 'raum',
      });
      final recordAblageort = RecordModel({
        'id': 'a1',
        'name': 'Ablageort',
        'type': 'ablageort',
      });

      final bereich = StorageNode.fromRecord(recordBereich);
      final raum = StorageNode.fromRecord(recordRaum);
      final ablageort = StorageNode.fromRecord(recordAblageort);

      // Bereich must not be placed anywhere
      expect(bereich.canBePlacedIn(raum), isFalse);

      // Raum can only be placed in Bereich
      expect(raum.canBePlacedIn(bereich), isTrue);
      expect(raum.canBePlacedIn(ablageort), isFalse);

      // Ablageort can be placed in Raum, Bereich or other Ablageort
      expect(ablageort.canBePlacedIn(raum), isTrue);
      expect(ablageort.canBePlacedIn(bereich), isTrue);
      expect(ablageort.canBePlacedIn(ablageort), isFalse); // Self loop protection
    });
  });
}
