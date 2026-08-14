import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'item_detail_screen.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Was suchst du?',
            border: InputBorder.none,
          ),
          onChanged: _performSearch,
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _results.length,
                  itemBuilder: (context, index) => _buildResultCard(_results[index]),
                ),
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

    // Pfad zusammenbauen aus Expand-Daten
    String path = 'Ohne Zuordnung';
    final containerRecord = item.record?.expand['container']?.first;
    if (containerRecord != null) {
      final roomName = containerRecord.expand['room']?.first.getStringValue('name') ?? 'Unbekannt';
      final containerName = containerRecord.getStringValue('name');
      
      // Prüfen ob Ablageort existiert UND nicht leer ist
      final locRecord = containerRecord.expand['storage_location']?.first;
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
