import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'pick_unassigned_items_screen.dart';
import 'qr_display_screen.dart'; 
import 'ui_components.dart';

class ItemListScreen extends StatefulWidget {
  final PocketBase pb;
  final StorageNode? node;
  final bool onlyUnassigned;

  const ItemListScreen({
    super.key, 
    required this.pb, 
    this.node, 
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
    if (widget.node != null) {
      filters.add('node = "${widget.node!.id}"');
    } else if (widget.onlyUnassigned && _searchQuery.isEmpty) {
      filters.add('node = ""');
    }
    if (_searchQuery.isNotEmpty) {
      filters.add('name ~ "$_searchQuery"');
    }
    final records = await widget.pb.collection('items').getFullList(
      filter: filters.isEmpty ? null : filters.join(' && '),
      sort: '-created',
      expand: 'node,tags',
    );
    return records.map((record) => Item.fromRecord(record)).toList();
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Gegenstände';
    String? subtitle;
    String? imageUrl;

    if (widget.node != null) {
      title = widget.node!.name;
      subtitle = 'In: ${widget.node!.type.label}';
      if (widget.node!.photo.isNotEmpty) {
        imageUrl = widget.pb.files.getUrl(widget.node!.record, widget.node!.photo).toString();
      }
    } else if (widget.onlyUnassigned) {
      title = 'Ohne Zuordnung';
    }

    return InventoryPageLayout(
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      actions: [
        if (widget.node != null)
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'QR-Code anzeigen',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QrDisplayScreen(container: widget.node))),
          ),
        const SizedBox(width: 16),
      ],
      filterBar: SearchBar(
        controller: _searchController,
        hintText: 'Suchen...',
        leading: const Icon(Icons.search, size: 20),
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(Theme.of(context).cardTheme.color),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onChanged: (val) {
          setState(() => _searchQuery = val.trim());
          _refreshItems();
        },
      ),
      sectionTitle: 'Artikel-Liste',
      floatingActionButton: InventoryActionFab(
        actions: [
          InventoryAction(
            label: 'Neuer Gegenstand',
            icon: Icons.label_outlined,
            isPrimary: true,
            onTap: () => _showAddItemDialog(context),
          ),
          if (widget.node != null)
            InventoryAction(
              label: 'Artikel hier einsortieren',
              icon: Icons.move_to_inbox_outlined,
              onTap: () async {
                final res = await Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => PickUnassignedItemsScreen(pb: widget.pb, targetNode: widget.node!))
                );
                if (res == true) _refreshItems();
              },
            ),
        ],
      ),
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
                  child: Center(child: Text('Hier ist momentan nichts zu finden.')),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                itemCount: items.length,
                itemBuilder: (context, index) => InventoryListTile(
                  entity: items[index],
                  pb: widget.pb,
                  onRefresh: _refreshItems,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => InventoryForm(
        title: 'Neuer Artikel',
        showQuantity: true,
        showTagSelector: true,
        pb: widget.pb,
        onSave: (name, quantity, imageFile, icon, labelId, type, tagIds) async {
          final Map<String, dynamic> body = {
            'name': name, 
            'quantity': quantity,
            'tags': tagIds,
          };
          if (widget.node != null) {
            body['node'] = widget.node!.id;
          }
          List<http.MultipartFile> files = [];
          if (imageFile != null) {
            files.add(await http.MultipartFile.fromPath('photo', imageFile.path));
          }
          try {
            await widget.pb.collection('items').create(body: body, files: files);
            if (context.mounted) Navigator.pop(context);
            _refreshItems();
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
          }
        },
      ),
    );
  }
}
