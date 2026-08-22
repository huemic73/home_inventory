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
  List<InventoryEntity> _results = [];
  List<Tag> _availableTags = [];
  final Set<String> _selectedTagIds = {};
  bool _isLoading = false;
  
  bool _showItems = true;
  bool _showContainers = true;
  bool _showLocations = true;
  bool _showAdvancedFilters = false;

  bool get _hasActiveFilters {
    return !_showItems || !_showContainers || !_showLocations || _selectedTagIds.isNotEmpty;
  }

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
      List<Item> itemResults = [];
      if (_showItems) {
        List<String> filterParts = [];
        
        if (query.isNotEmpty) {
          filterParts.add('(name ~ "$query" || description ~ "$query" || tags.name ~ "$query")');
        }
        
        for (var id in _selectedTagIds) {
          filterParts.add('tags ~ "$id"');
        }

        if (filterParts.isNotEmpty) {
          final String filter = filterParts.join(' && ');
          final records = await widget.pb.collection('items').getFullList(
            filter: filter,
            expand: 'node.parent.parent.parent.parent,tags',
            sort: 'name',
          );
          itemResults = records.map((r) => Item.fromRecord(r)).toList();
        }
      }

      List<StorageNode> nodeResults = [];
      if (_selectedTagIds.isEmpty && query.isNotEmpty && (_showContainers || _showLocations)) {
        List<String> nodeFilters = ['name ~ "$query"'];
        if (!_showContainers) {
          nodeFilters.add('type != "container"');
        } else if (!_showLocations) {
          nodeFilters.add('type = "container"');
        }
        final nodeFilter = nodeFilters.join(' && ');

        final nodeRecords = await widget.pb.collection('nodes').getFullList(
          filter: nodeFilter,
          expand: 'parent',
          sort: 'name',
        );
        nodeResults = nodeRecords.map((r) => StorageNode.fromRecord(r)).toList();
      }

      if (mounted) {
        setState(() {
          _results = [...itemResults, ...nodeResults];
          _results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  Widget _buildTypeChip(String label, IconData icon, bool isSelected, ValueChanged<bool> onSelected) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : primaryColor),
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
        selected: isSelected,
        selectedColor: primaryColor,
        onSelected: onSelected,
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: primaryColor.withAlpha(50)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InventoryPageLayout(
      title: 'Gegenstandssuche',
      subtitle: 'Gesamtes Inventar durchsuchen',
      filterBar: SearchBar(
        controller: _searchController,
        hintText: 'Nach Name oder Ort suchen...',
        leading: const Icon(Icons.search, size: 20),
        trailing: [
          IconButton(
            icon: Icon(
              _showAdvancedFilters ? Icons.tune : Icons.filter_list,
              color: _hasActiveFilters ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () {
              setState(() {
                _showAdvancedFilters = !_showAdvancedFilters;
              });
            },
          ),
        ],
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(Theme.of(context).cardTheme.color),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        onChanged: (val) => _performSearch(),
      ),
      sectionTitle: _results.isNotEmpty ? 'Suchergebnisse' : (_searchController.text.isEmpty && _selectedTagIds.isEmpty ? 'Kategorien durchsuchen' : null),
      slivers: [
        SliverToBoxAdapter(
          child: AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 24, right: 24, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Was möchtest du suchen?',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildTypeChip('Artikel', Icons.label_outlined, _showItems, (val) {
                        setState(() {
                          _showItems = val;
                        });
                        _performSearch();
                      }),
                      _buildTypeChip('Boxen', Icons.inventory_2_outlined, _showContainers, (val) {
                        setState(() {
                          _showContainers = val;
                        });
                        _performSearch();
                      }),
                      _buildTypeChip('Ablageorte', Icons.shelves, _showLocations, (val) {
                        setState(() {
                          _showLocations = val;
                        });
                        _performSearch();
                      }),
                    ],
                  ),
                  if (_availableTags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Nach Tags filtern:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _availableTags.map((tag) {
                          final isSelected = _selectedTagIds.contains(tag.id);
                          final adaptiveColor = tag.getAdaptiveColor(context);
                          final textColor = isSelected
                              ? (adaptiveColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                              : null;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(tag.name, style: TextStyle(fontSize: 12, color: textColor)),
                              selected: isSelected,
                              selectedColor: adaptiveColor,
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
                              side: BorderSide(color: adaptiveColor.withAlpha(50)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: _showAdvancedFilters 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ),
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
