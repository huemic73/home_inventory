import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/material.dart';

class Room {
  final String id;
  final String name;
  final String iconName;
  final RecordModel record;

  Room({required this.id, required this.name, required this.iconName, required this.record});

  factory Room.fromRecord(RecordModel record) {
    final icon = record.getStringValue('icon');
    return Room(
      id: record.id,
      name: record.getStringValue('name'),
      iconName: icon.isEmpty ? 'meeting_room' : icon,
      record: record,
    );
  }

  IconData get iconData => iconMapping[iconName] ?? Icons.meeting_room;
}

class StorageLocation {
  final String id;
  final String name;
  final String roomId;
  final String iconName;
  final String photo; // Neu: Foto für Ablageort
  final RecordModel record;

  StorageLocation({required this.id, required this.name, required this.roomId, required this.iconName, required this.photo, required this.record});

  factory StorageLocation.fromRecord(RecordModel record) {
    final icon = record.getStringValue('icon');
    return StorageLocation(
      id: record.id,
      name: record.getStringValue('name'),
      roomId: record.getStringValue('room'),
      iconName: icon.isEmpty ? 'shelves' : icon,
      photo: record.getStringValue('photo'),
      record: record,
    );
  }

  IconData get iconData => iconMapping[iconName] ?? Icons.shelves;
}

class InventoryContainer {
  final String id;
  final String name;
  final String roomId;
  final String? storageLocationId; // Optionaler Ablageort
  final String iconName;
  final String labelId;
  final String photo;
  final RecordModel record;

  InventoryContainer({
    required this.id, 
    required this.name, 
    required this.roomId, 
    this.storageLocationId,
    required this.iconName,
    required this.labelId,
    required this.photo,
    required this.record
  });

  factory InventoryContainer.fromRecord(RecordModel record) {
    final icon = record.getStringValue('icon');
    return InventoryContainer(
      id: record.id,
      name: record.getStringValue('name'),
      roomId: record.getStringValue('room'),
      storageLocationId: record.getStringValue('storage_location'),
      iconName: icon.isEmpty ? 'inventory_2' : icon,
      labelId: record.getStringValue('labelId'),
      photo: record.getStringValue('photo'),
      record: record,
    );
  }

  IconData get iconData => iconMapping[iconName] ?? Icons.inventory_2;
}

class Item {
  final String id;
  final String name;
  final int quantity;
  final String photo;
  final String? containerId;
  final RecordModel? record;

  Item({
    required this.id,
    required this.name,
    required this.quantity,
    required this.photo,
    this.containerId,
    this.record,
  });

  factory Item.fromRecord(RecordModel record) {
    return Item(
      id: record.id,
      name: record.getStringValue('name'),
      quantity: record.getIntValue('quantity'),
      photo: record.getStringValue('photo'),
      containerId: record.getStringValue('container'),
      record: record,
    );
  }
}

// Zentrales Mapping für Icons
final Map<String, IconData> iconMapping = {
  'meeting_room': Icons.meeting_room,
  'kitchen': Icons.kitchen,
  'garage': Icons.garage,
  'weekend': Icons.weekend, // Wohnzimmer
  'bed': Icons.bed,
  'build': Icons.build, // Werkstatt
  'warehouse': Icons.warehouse, // Keller
  'deck': Icons.deck, // Terrasse/Garten
  'inventory_2': Icons.inventory_2,
  'archive': Icons.archive,
  'shopping_basket': Icons.shopping_basket,
  'shelves': Icons.shelves, // Neues Icon für Ablageort
  'door_sliding': Icons.door_sliding, // Schrank
  'home_repair_service': Icons.home_repair_service, // Werkbank
};
