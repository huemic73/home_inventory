import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'item_detail_screen.dart';
import 'add_item_screen.dart';
import 'pick_unassigned_items_screen.dart'; // Import hinzugefügt

class ItemListScreen extends StatefulWidget {
  final PocketBase pb;
  final InventoryContainer? container;
  final Room? room; // Optional: Raum-Info für die Anzeige
  final bool onlyUnassigned;

  const ItemListScreen({
    super.key, 
    required this.pb, 
    this.container, 
    this.room, 
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
    );
    return records.map((record) => Item.fromRecord(record)).toList();
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Gegenstände';
    String? subtitle;

    if (widget.container != null) {
      title = widget.container!.name;
      if (widget.room != null) {
        subtitle = 'In Raum: ${widget.room!.name}';
      }
    } else if (widget.onlyUnassigned) {
      title = 'Ohne Zuordnung';
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'In $title suchen...',
                  leading: const Icon(Icons.search),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                    _refreshItems();
                  },
                  elevation: WidgetStateProperty.all(0),
                  backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)),
                ),
              ),
            ),
          ),
          FutureBuilder<List<Item>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const SliverFillRemaining(child: Center(child: Text('Keine Gegenstände gefunden.')));
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildItemTile(context, items[index]),
                  childCount: items.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.container != null) ...[
            FloatingActionButton.extended(
              heroTag: 'pick_existing',
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PickUnassignedItemsScreen(
                      pb: widget.pb,
                      targetContainer: widget.container!,
                    ),
                  ),
                );
                if (res == true) _refreshItems();
              },
              icon: const Icon(Icons.playlist_add),
              label: const Text('Bestehende wählen'),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'add_new',
            onPressed: () async {
              final res = await Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => AddItemScreen(
                    pb: widget.pb, 
                    container: widget.container
                  ),
                ),
              );
              if (res == true) _refreshItems();
            },
            icon: const Icon(Icons.add),
            label: const Text('Neu anlegen'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, Item item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildLeading(item),
      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${item.quantity} Stück'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item, pb: widget.pb)));
        _refreshItems();
      },
    );
  }

  Widget _buildLeading(Item item) {
    String imageUrl = '';
    if (item.photo.isNotEmpty && item.record != null) {
      imageUrl = widget.pb.files.getUrl(item.record!, item.photo).toString();
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl.isNotEmpty
            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
            : const Icon(Icons.inventory_2_outlined),
      ),
    );
  }
}
