import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
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
  final Set<String> _selectedTagIds = {};
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
    
    if (query.length < 2 && _selectedTagIds.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      List<String> filterParts = [];
      
      if (query.isNotEmpty) {
        filterParts.add('(name ~ "$query" || description ~ "$query" || tags.name ~ "$query")');
      }
      
      for (var id in _selectedTagIds) {
        filterParts.add('tags ~ "$id"');
      }

      final String filter = filterParts.join(' && ');

      final records = await widget.pb.collection('items').getFullList(
        filter: filter,
        expand: 'node.parent.parent.parent.parent,tags',
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
      title: 'Gegenstandssuche',
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
                (context, index) => InventoryListTile(
                  entity: _results[index],
                  pb: widget.pb,
                  onRefresh: _performSearch,
                ),
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

}
