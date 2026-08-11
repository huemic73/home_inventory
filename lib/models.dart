import 'package:pocketbase/pocketbase.dart';

class Room {
  final String id;
  final String name;
  final RecordModel record;

  Room({required this.id, required this.name, required this.record});

  factory Room.fromRecord(RecordModel record) {
    return Room(
      id: record.id,
      name: record.getStringValue('name'),
      record: record,
    );
  }
}

class InventoryContainer {
  final String id;
  final String name;
  final String roomId;
  final RecordModel record;

  InventoryContainer({
    required this.id, 
    required this.name, 
    required this.roomId, 
    required this.record
  });

  factory InventoryContainer.fromRecord(RecordModel record) {
    return InventoryContainer(
      id: record.id,
      name: record.getStringValue('name'),
      roomId: record.getStringValue('room'),
      record: record,
    );
  }
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
