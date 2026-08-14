import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'item_detail_screen.dart';
import 'add_item_screen.dart';
import 'pick_unassigned_items_screen.dart';

import 'qr_display_screen.dart'; // Import hinzugefügt

class ItemListScreen extends StatefulWidget {
  final PocketBase pb;
  final InventoryContainer? container;
  final Room? room;
  final StorageLocation? storageLocation; // Neu: Für die volle Pfadanzeige
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
      expand: 'container,container.room,container.storage_location', // Alles expandieren
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: containerImageUrl != null ? 250 : 160,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: containerImageUrl != null ? Colors.white : Theme.of(context).colorScheme.onSurface,
            actions: [
              if (widget.container != null)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: containerImageUrl != null ? Colors.white24 : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (containerImageUrl == null)
                          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)
                      ],
                    ),
                    child: Icon(
                      Icons.qr_code, 
                      color: containerImageUrl != null ? Colors.white : Theme.of(context).colorScheme.primary, 
                      size: 20
                    ),
                  ),
                  tooltip: 'Box QR-Code anzeigen',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => QrDisplayScreen(container: widget.container!)),
                  ),
                ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: containerImageUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(containerImageUrl, fit: BoxFit.cover),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black54, Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).colorScheme.primary.withAlpha(20),
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                    ),
              titlePadding: const EdgeInsetsDirectional.only(start: 64, bottom: 16, end: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: containerImageUrl != null ? Colors.white : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: containerImageUrl != null ? Colors.white70 : Theme.of(context).colorScheme.primary.withAlpha(150),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  Text(
                    'Inhalt der Box',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  FutureBuilder<List<Item>>(
                    future: _itemsFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count Artikel',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Im Inhalt suchen...',
                leading: const Icon(Icons.search, size: 20),
                elevation: WidgetStateProperty.all(0),
                backgroundColor: WidgetStateProperty.all(Colors.white),
                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                  _refreshItems();
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: FutureBuilder<List<Item>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text('Diese Box ist momentan leer.'),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildItemCard(context, items[index]),
                    ),
                    childCount: items.length,
                  ),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
      floatingActionButton: _buildFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildItemCard(BuildContext context, Item item) {
    String imageUrl = '';
    if (item.photo.isNotEmpty && item.record != null) {
      imageUrl = widget.pb.files.getUrl(item.record!, item.photo).toString();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                : Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.primary.withAlpha(100)),
          ),
        ),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${item.quantity} Stück', style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(150))),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item, pb: widget.pb)));
          _refreshItems();
        },
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.container != null) ...[
          FloatingActionButton.extended(
            heroTag: 'pick_existing',
            onPressed: () async {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => PickUnassignedItemsScreen(pb: widget.pb, targetContainer: widget.container!)));
              if (res == true) _refreshItems();
            },
            icon: const Icon(Icons.playlist_add),
            label: const Text('Bestehende wählen'),
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
            elevation: 2,
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton.extended(
          heroTag: 'add_new',
          onPressed: () async {
            final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddItemScreen(pb: widget.pb, container: widget.container)));
            if (res == true) _refreshItems();
          },
          icon: const Icon(Icons.add),
          label: const Text('Neu anlegen'),
        ),
      ],
    );
  }
}
