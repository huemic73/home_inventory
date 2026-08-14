import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'item_detail_screen.dart';
import 'ui_components.dart'; // Import hinzugefügt

class GlobalSearchScreen extends StatefulWidget {
  final PocketBase pb;
  const GlobalSearchScreen({super.key, required this.pb});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  List<Item> _results = [];
  bool _isLoading = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final records = await widget.pb.collection('items').getFullList(
        filter: 'name ~ "$query"',
        expand: 'container,container.room,container.storage_location',
        sort: 'name',
      );

      if (mounted) {
        setState(() {
          _results = records.map((r) => Item.fromRecord(r)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InventoryPageLayout(
      title: 'Artikelsuche',
      subtitle: 'Gesamtes Inventar durchsuchen',
      filterBar: SearchBar(
        controller: _searchController,
        hintText: 'Was suchst du?',
        leading: const Icon(Icons.search, size: 20),
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(Theme.of(context).cardTheme.color),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onChanged: _performSearch,
      ),
      sectionTitle: _results.isNotEmpty ? 'Suchergebnisse' : null,
      slivers: [
        if (_isLoading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_results.isEmpty)
          SliverFillRemaining(child: _buildEmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildResultCard(_results[index]),
                childCount: _results.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.withAlpha(50)),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty ? 'Tippe etwas ein, um zu suchen' : 'Nichts gefunden',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Item item) {
    String imageUrl = '';
    if (item.photo.isNotEmpty && item.record != null) {
      imageUrl = widget.pb.files.getUrl(item.record!, item.photo).toString();
    }

    // Pfad zusammenbauen mit moderner .get<T> Logik
    String path = 'Ohne Zuordnung';
    final containerRecord = item.record?.get<RecordModel?>('expand.container');
    
    if (containerRecord != null) {
      final roomName = containerRecord.get<RecordModel?>('expand.room')?.getStringValue('name') ?? 'Unbekannt';
      final containerName = containerRecord.getStringValue('name');
      
      final locRecord = containerRecord.get<RecordModel?>('expand.storage_location');
      final locName = locRecord?.getStringValue('name');
      
      if (locName != null && locName.isNotEmpty) {
        path = '$roomName > $locName > $containerName';
      } else {
        path = '$roomName > $containerName';
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(15), borderRadius: BorderRadius.circular(16)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover)
                : Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.primary.withAlpha(150)),
          ),
        ),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.quantity} Stück', style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(200), fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(path, style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
        ),
        onTap: () async {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item, pb: widget.pb))
          );
          // Falls verschoben oder gelöscht wurde (result == true), Liste aktualisieren
          if (result == true) {
            _performSearch(_searchController.text);
          }
        },
      ),
    );
  }
}
