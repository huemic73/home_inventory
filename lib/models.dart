import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/material.dart';
import 'item_detail_screen.dart';
import 'container_list_screen.dart';

// Zentrale Konfiguration für QR-Codes (v2.0)
const String qrBaseUrl = 'https://home-inventory.app';

enum NodeType {
  area,      // z.B. Erdgeschoss, Garten
  room,      // z.B. Küche, Werkstatt
  location,  // z.B. Regal, Schrank
  container  // z.B. Kiste, Tasche
}

extension NodeTypeExtension on NodeType {
  String get label {
    switch (this) {
      case NodeType.area: return 'Bereich';
      case NodeType.room: return 'Raum';
      case NodeType.location: return 'Ort / Regal';
      case NodeType.container: return 'Box / Kiste';
    }
  }

  /// Welcher Typ wird normalerweise in diesem Typ erstellt?
  NodeType get defaultChildType {
    switch (this) {
      case NodeType.area: return NodeType.room;
      case NodeType.room: return NodeType.location;
      case NodeType.location: return NodeType.container;
      case NodeType.container: return NodeType.container;
    }
  }
}

/// Gemeinsames Interface für alles, was in Listen angezeigt werden kann
abstract class InventoryEntity {
  String get id;
  String get name;
  String? get photo;
  String get secondaryInfo; 
  IconData get icon;
  List<Tag> get tags;
  RecordModel? get record;
  
  VoidCallback getAction(BuildContext context, PocketBase pb, {VoidCallback? onRefresh});
}

class StorageNode implements InventoryEntity {
  @override
  final String id;
  @override
  final String name;
  final NodeType type;
  final String iconName;
  @override
  final String photo;
  final String labelId;
  final String? parentId;
  @override
  final RecordModel record;

  StorageNode({
    required this.id,
    required this.name,
    required this.type,
    required this.iconName,
    required this.photo,
    required this.labelId,
    this.parentId,
    required this.record,
  });

  factory StorageNode.fromRecord(RecordModel record) {
    final typeString = record.getStringValue('type');
    final type = NodeType.values.firstWhere(
      (e) => e.name == typeString,
      orElse: () => NodeType.container,
    );

    return StorageNode(
      id: record.id,
      name: record.getStringValue('name'),
      type: type,
      iconName: record.getStringValue('icon'),
      photo: record.getStringValue('photo'),
      labelId: record.getStringValue('labelId'),
      parentId: record.getStringValue('parent'),
      record: record,
    );
  }

  IconData get iconData {
    if (iconName.isNotEmpty && iconMapping.containsKey(iconName)) {
      return iconMapping[iconName]!;
    }
    // Fallbacks je nach Typ
    switch (type) {
      case NodeType.area: return Icons.domain;
      case NodeType.room: return Icons.meeting_room;
      case NodeType.location: return Icons.shelves;
      case NodeType.container: return Icons.inventory_2_outlined;
    }
  }

  @override
  IconData get icon => iconData;

  @override
  String get secondaryInfo => type.label;

  @override
  List<Tag> get tags => []; // Nodes haben aktuell keine Tags in der DB

  @override
  VoidCallback getAction(BuildContext context, PocketBase pb, {VoidCallback? onRefresh}) {
    return () async {
      await Navigator.push(context, MaterialPageRoute(
        builder: (context) => ContainerListScreen(pb: pb, parentNode: this)
      ));
      if (onRefresh != null) onRefresh();
    };
  }

  /// Hilfsmethode: Darf diese Node Kinder vom Typ Node enthalten?
  bool get canContainNodes => type != NodeType.container || true; // Container-in-Container erlaubt

  /// Typschutz-Logik (wie im Test entwickelt)
  bool canBePlacedIn(StorageNode potentialParent) {
    if (potentialParent.id == id) return false;
    
    switch (type) {
      case NodeType.area:
        return false;
      case NodeType.room:
        return potentialParent.type == NodeType.area;
      case NodeType.location:
        return potentialParent.type == NodeType.room || potentialParent.type == NodeType.area;
      case NodeType.container:
        return true; // Darf fast überall rein
    }
  }
}

class Item implements InventoryEntity {
  @override
  final String id;
  @override
  final String name;
  final int quantity;
  @override
  final String photo;
  final String? nodeId; // Verweis auf die neue StorageNode
  final List<String> tagIds; // Neu: Liste der Tag-IDs
  @override
  final RecordModel? record;

  Item({
    required this.id,
    required this.name,
    required this.quantity,
    required this.photo,
    this.nodeId,
    this.tagIds = const [],
    this.record,
  });

  factory Item.fromRecord(RecordModel record) {
    return Item(
      id: record.id,
      name: record.getStringValue('name'),
      quantity: record.getIntValue('quantity'),
      photo: record.getStringValue('photo'),
      nodeId: record.getStringValue('node'),
      tagIds: record.getListValue<String>('tags'),
      record: record,
    );
  }

  @override
  IconData get icon => Icons.label_outlined;

  @override
  String get secondaryInfo {
    final nodeName = record?.get<RecordModel?>('expand.node')?.getStringValue('name') ?? '';
    if (nodeName.isNotEmpty) {
      return '$quantity Stück · $nodeName';
    }
    return '$quantity Stück';
  }

  @override
  List<Tag> get tags {
    final expandedTags = record?.get<List<dynamic>?>('expand.tags') ?? [];
    return expandedTags
        .whereType<RecordModel>()
        .map((r) => Tag.fromRecord(r))
        .toList();
  }

  @override
  VoidCallback getAction(BuildContext context, PocketBase pb, {VoidCallback? onRefresh}) {
    return () async {
      final res = await Navigator.push(context, MaterialPageRoute(
        builder: (context) => ItemDetailScreen(item: this, pb: pb)
      ));
      if (res == true) onRefresh?.call();
    };
  }
}

class Tag {
  final String id;
  final String name;
  final String color; // Hex-Code
  final RecordModel record;

  Tag({required this.id, required this.name, required this.color, required this.record});

  factory Tag.fromRecord(RecordModel record) {
    return Tag(
      id: record.id,
      name: record.getStringValue('name'),
      color: record.getStringValue('color'),
      record: record,
    );
  }

  Color get colorData {
    if (color.isEmpty) return Colors.grey;
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

// Zentrales Mapping für Icons, gruppiert nach Typ für die UI
final Map<NodeType, List<String>> iconsByType = {
  NodeType.area: ['area', 'warehouse', 'deck', 'garage'],
  NodeType.room: ['meeting_room', 'kitchen', 'weekend', 'bed', 'build', 'garage', 'warehouse', 'deck'],
  NodeType.location: ['shelves', 'door_sliding', 'home_repair_service'],
  NodeType.container: ['inventory_2', 'archive', 'shopping_basket'],
};

final Map<String, IconData> iconMapping = {
  'area': Icons.domain,
  'meeting_room': Icons.meeting_room,
  'kitchen': Icons.kitchen,
  'garage': Icons.garage,
  'weekend': Icons.weekend,
  'bed': Icons.bed,
  'build': Icons.build,
  'warehouse': Icons.warehouse,
  'deck': Icons.deck,
  'inventory_2': Icons.inventory_2,
  'archive': Icons.archive,
  'shopping_basket': Icons.shopping_basket,
  'shelves': Icons.shelves,
  'door_sliding': Icons.door_sliding,
  'home_repair_service': Icons.home_repair_service,
};
