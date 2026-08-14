import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'item_detail_screen.dart';
import 'pick_unassigned_items_screen.dart';
import 'qr_display_screen.dart'; 
import 'ui_components.dart';

class ItemListScreen extends StatefulWidget {
  final PocketBase pb;
  final InventoryContainer? container;
  final Room? room;
  final StorageLocation? storageLocation;
  final bool onlyUnassigned;

  const ItemListScreen({
    super.key, 
    required this.pb, 
    this.container, 
    this.room, 
    this.storageLocation,
    this.onlyUnassigned = false
  });

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  late Future<List<Item>> _itemsFuture;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshItems();
  }

  void _refreshItems() {
    _itemsFuture = _fetchItems();
    setState(() {});
  }

  Future<List<Item>> _fetchItems() async {
    List<String> filters = [];
    if (widget.container != null) {
      filters.add('container = "${widget.container!.id}"');
    } else if (widget.onlyUnassigned && _searchQuery.isEmpty) {
      filters.add('container = ""');
    }
    if (_searchQuery.isNotEmpty) {
      filters.add('name ~ "$_searchQuery"');
    }
    final records = await widget.pb.collection('items').getFullList(
      filter: filters.isEmpty ? null : filters.join(' && '),
      sort: '-created',
      expand: 'container,container.room,container.storage_location',
    );
    return records.map((record) => Item.fromRecord(record)).toList();
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Gegenstände';
    String? subtitle;
    String? containerImageUrl;

    if (widget.container != null) {
      title = widget.container!.name;
      if (widget.room != null) {
        subtitle = 'In: ${widget.room!.name}';
        if (widget.storageLocation != null) {
          subtitle += ' > ${widget.storageLocation!.name}';
        }
      }
      if (widget.container!.photo.isNotEmpty) {
        containerImageUrl = widget.pb.files.getUrl(widget.container!.record, widget.container!.photo).toString();
      }
    } else if (widget.onlyUnassigned) {
      title = 'Ohne Zuordnung';
    }

    return InventoryPageLayout(
      title: title,
      subtitle: subtitle,
      imageUrl: containerImageUrl,
      actions: [
        if (widget.container != null)
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'Box QR-Code anzeigen',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QrDisplayScreen(container: widget.container!))),
          ),
        const SizedBox(width: 16),
      ],
      filterBar: SearchBar(
        controller: _searchController,
        hintText: 'In dieser Box suchen...',
        leading: const Icon(Icons.search, size: 20),
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(Theme.of(context).cardTheme.color),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onChanged: (val) {
          setState(() => _searchQuery = val.trim());
          _refreshItems();
        },
      ),
      sectionTitle: 'Inhalt der Box',
      floatingActionButton: _buildFab(context),
      slivers: [
        SliverToBoxAdapter(
          child: FutureBuilder<List<Item>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(child: Text('Diese Box ist momentan leer.')),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                itemCount: items.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildItemCard(context, items[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, Item item) {
    String imageUrl = '';
    if (item.photo.isNotEmpty && item.record != null) {
      imageUrl = widget.pb.files.getUrl(item.record!, item.photo).toString();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(24), boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(15), borderRadius: BorderRadius.circular(16)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl.isNotEmpty ? Image.network(imageUrl, fit: BoxFit.cover) : Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.primary.withAlpha(150)),
          ),
        ),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${item.quantity} Stück', style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(200))),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item, pb: widget.pb)));
          _refreshItems();
        },
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.container != null) ...[
          StandardFab(
            heroTag: 'pick_existing',
            label: 'Bestehende wählen',
            icon: Icons.playlist_add,
            onPressed: () async {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => PickUnassignedItemsScreen(pb: widget.pb, targetContainer: widget.container!)));
              if (res == true) {
                _refreshItems();
              }
            },
            backgroundColor: isDark ? const Color(0xFF2D2F36) : Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
        ],
        StandardFab(heroTag: 'add_new', label: 'Artikel', onPressed: () => _showAddItemDialog(context)),
      ],
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => InventoryForm(
        title: 'Neuer Artikel',
        showQuantity: true,
        pb: widget.pb,
        onSave: (name, quantity, imageFile, icon, labelId) async {
          final Map<String, dynamic> body = {'name': name, 'quantity': quantity};
          if (widget.container != null) {
            body['container'] = widget.container!.id;
          }
          List<http.MultipartFile> files = [];
          if (imageFile != null) {
            if (kIsWeb) {
              files.add(http.MultipartFile.fromBytes('photo', await imageFile.readAsBytes(), filename: imageFile.name));
            } else {
              files.add(await http.MultipartFile.fromPath('photo', imageFile.path));
            }
          }
          try {
            await widget.pb.collection('items').create(body: body, files: files);
            if (context.mounted) {
              Navigator.pop(context);
            }
            _refreshItems();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
            }
          }
        },
      ),
    );
  }
}
