import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'item_detail_screen.dart';
import 'ui_components.dart';

class GlobalSearchScreen extends StatefulWidget {
  final PocketBase pb;
  const GlobalSearchScreen({super.key, required this.pb});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  List<Item> _results = [];
  List<Tag> _availableTags = [];
  final Set<String> _selectedTagIds = {}; // Neu: Mehrere Tags möglich
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final records = await widget.pb.collection('tags').getFullList(sort: 'name');
      setState(() {
        _availableTags = records.map((r) => Tag.fromRecord(r)).toList();
      });
    } catch (e) {
      debugPrint('Tags konnten nicht geladen werden: $e');
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    
    // Suche nur starten, wenn Text vorhanden ist ODER Tags gewählt wurden
    if (query.length < 2 && _selectedTagIds.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      List<String> filterParts = [];
      
      // 1. Text-Filter hinzufügen
      if (query.isNotEmpty) {
        filterParts.add('(name ~ "$query" || tags.name ~ "$query")');
      }
      
      // 2. Jede Tag-ID als eigenen Filter hinzufügen (AND-Verknüpfung)
      for (var id in _selectedTagIds) {
        filterParts.add('tags ~ "$id"');
      }

      final String filter = filterParts.join(' && ');

      final records = await widget.pb.collection('items').getFullList(
        filter: filter,
        expand: 'node,tags',
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
        hintText: 'Nach Name oder Tag suchen...',
        leading: const Icon(Icons.search, size: 20),
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(Theme.of(context).cardTheme.color),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onChanged: (val) => _performSearch(),
      ),
      filterChips: _availableTags.map((tag) {
        final isSelected = _selectedTagIds.contains(tag.id);
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: FilterChip(
            label: Text(tag.name, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
            selected: isSelected,
            selectedColor: tag.colorData,
            onSelected: (val) {
              setState(() {
                if (val) {
                  _selectedTagIds.add(tag.id);
                } else {
                  _selectedTagIds.remove(tag.id);
                }
              });
              _performSearch();
            },
            showCheckmark: false,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: tag.colorData.withAlpha(50)),
          ),
        );
      }).toList(),
      sectionTitle: _results.isNotEmpty ? 'Suchergebnisse' : (_searchController.text.isEmpty && _selectedTagIds.isEmpty ? 'Kategorien durchsuchen' : null),
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
            (_searchController.text.isEmpty && _selectedTagIds.isEmpty) 
                ? 'Tippe etwas ein oder wähle Tags' 
                : 'Nichts gefunden',
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

    String path = 'Ohne Zuordnung';
    final nodeRecord = item.record?.get<RecordModel?>('expand.node');
    if (nodeRecord != null) {
      path = nodeRecord.getStringValue('name');
    }

    final tags = item.record?.get<List<RecordModel>?>('expand.tags') ?? [];

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
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: tags.map((t) {
                  final tag = Tag.fromRecord(t);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tag.colorData.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag.name,
                      style: TextStyle(color: tag.colorData, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        onTap: () async {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item, pb: widget.pb))
          );
          if (result == true) {
            _performSearch();
          }
        },
      ),
    );
  }
}

  Widget _buildResultCard(Item item) {
    String imageUrl = '';
    if (item.photo.isNotEmpty && item.record != null) {
      imageUrl = widget.pb.files.getUrl(item.record!, item.photo).toString();
    }

    String path = 'Ohne Zuordnung';
    final nodeRecord = item.record?.get<RecordModel?>('expand.node');
    if (nodeRecord != null) {
      path = nodeRecord.getStringValue('name');
    }

    final tags = item.record?.get<List<RecordModel>?>('expand.tags') ?? [];

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
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: tags.map((t) {
                  final tag = Tag.fromRecord(t);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tag.colorData.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag.name,
                      style: TextStyle(color: tag.colorData, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        onTap: () async {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item, pb: widget.pb))
          );
          if (result == true) {
            _performSearch(_searchController.text);
          }
        },
      ),
    );
  }
}
