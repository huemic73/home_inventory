import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'item_detail_screen.dart';
import 'add_item_screen.dart';

class ItemListScreen extends StatefulWidget {
  final PocketBase pb;
  final InventoryContainer? container; // Optionaler Filter
  final bool onlyUnassigned; // Neu: Filter für lose Gegenstände

  const ItemListScreen({
    super.key, 
    required this.pb, 
    this.container, 
    this.onlyUnassigned = false,
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshItems() {
    setState(() {
      _itemsFuture = _fetchItems();
    });
  }

  Future<List<Item>> _fetchItems() async {
    List<String> filters = [];
    
    if (widget.container != null) {
      filters.add('container = "${widget.container!.id}"');
    } else if (widget.onlyUnassigned && _searchQuery.isEmpty) {
      // Nur Items zeigen, die KEINEN Container haben
      filters.add('container = ""');
    }
    
    if (_searchQuery.isNotEmpty) {
      filters.add('name ~ "$_searchQuery"');
    }

    final String filterString = filters.join(' && ');

    final records = await widget.pb.collection('items').getFullList(
      filter: filterString.isEmpty ? null : filterString,
      sort: '-created',
    );

    return records.map((record) => Item.fromRecord(record)).toList();
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Gegenstände';
    if (widget.container != null) {
      title = 'Inhalt: ${widget.container!.name}';
    } else if (widget.onlyUnassigned) {
      title = 'Ohne Zuordnung';
    } else {
      title = 'Alle Gegenstände';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Suchen...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _refreshItems();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
                _refreshItems();
              },
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshItems,
          ),
        ],
      ),
      body: FutureBuilder<List<Item>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Keine Gegenstände gefunden.'));
          }

          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: _buildLeading(item),
                title: Text(item.name),
                subtitle: Text('${item.quantity} Stück'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemDetailScreen(
                        item: item,
                        pb: widget.pb,
                      ),
                    ),
                  );
                  _refreshItems();
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddItemScreen(
                pb: widget.pb, 
                container: widget.container
              ),
            ),
          );
          if (result == true) {
            _refreshItems();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLeading(Item item) {
    if (item.photo.isEmpty || item.record == null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2),
      );
    }

    final imageUrl = widget.pb.files.getUrl(item.record!, item.photo).toString();
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
        ),
      ),
    );
  }
}
