import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';

class MoveItemScreen extends StatefulWidget {
  final PocketBase pb;
  final Item item;

  const MoveItemScreen({super.key, required this.pb, required this.item});

  @override
  State<MoveItemScreen> createState() => _MoveItemScreenState();
}

class _MoveItemScreenState extends State<MoveItemScreen> {
  late Future<List<StorageNode>> _nodesFuture;
  List<StorageNode> _allNodes = [];
  List<StorageNode> _filteredNodes = [];
  String _searchQuery = '';
  String? _selectedNodeId;
  NodeType? _selectedTypeFilter;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nodesFuture = _fetchNodes();
    _selectedNodeId = widget.item.nodeId;
  }

  Future<List<StorageNode>> _fetchNodes() async {
    final records = await widget.pb.collection('nodes').getFullList(sort: 'name');
    _allNodes = records.map((r) => StorageNode.fromRecord(r)).toList();
    _applyFilters();
    return _allNodes;
  }

  void _applyFilters() {
    setState(() {
      _filteredNodes = _allNodes.where((node) {
        final matchesQuery = node.name.toLowerCase().contains(_searchQuery);
        final matchesType = _selectedTypeFilter == null || node.type == _selectedTypeFilter;
        return matchesQuery && matchesType;
      }).toList();
    });
  }

  void _filterList(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
  }

  List<StorageNode> _getNodePath(StorageNode node) {
    final List<StorageNode> path = [];
    StorageNode? current = node;
    final Set<String> visited = {node.id};

    while (current != null && current.parentId != null && current.parentId!.isNotEmpty) {
      final String nextParentId = current.parentId!;
      if (!visited.add(nextParentId)) {
        break; // Zyklus-Schutz
      }

      final parent = _allNodes.cast<StorageNode?>().firstWhere(
        (n) => n?.id == nextParentId,
        orElse: () => null,
      );

      if (parent != null) {
        path.insert(0, parent);
        current = parent;
      } else {
        break;
      }
    }
    return path;
  }

  String _getPathString(List<StorageNode> path) {
    if (path.isEmpty) return '';
    return path.map((n) => n.name).join(' › ');
  }

  Widget _buildFilterChip(NodeType? type, String label) {
    final isSelected = _selectedTypeFilter == type;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primary,
      onSelected: (val) {
        setState(() {
          _selectedTypeFilter = type;
          _applyFilters();
        });
      },
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(
        color: isSelected 
            ? Theme.of(context).colorScheme.primary 
            : Colors.grey.withOpacity(0.3)
      ),
    );
  }

  Future<void> _saveMove() async {
    setState(() => _isSaving = true);
    try {
      await widget.pb.collection('items').update(
        widget.item.id,
        body: {'node': _selectedNodeId ?? ''},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Artikel verschieben', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(30)))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verschiebe Artikel:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(widget.item.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Suche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Nach neuem Ort suchen...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: _filterList,
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterChip(null, 'Alle'),
                const SizedBox(width: 8),
                _buildFilterChip(NodeType.bereich, 'Bereiche'),
                const SizedBox(width: 8),
                _buildFilterChip(NodeType.raum, 'Räume'),
                const SizedBox(width: 8),
                _buildFilterChip(NodeType.ablageort, 'Regale / Orte'),
                const SizedBox(width: 8),
                _buildFilterChip(NodeType.container, 'Boxen / Kisten'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Liste
          Expanded(
            child: FutureBuilder<List<StorageNode>>(
              future: _nodesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredNodes.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildTargetTile(null, 'Lose (keinem Ort zugeordnet)', Icons.inventory_2_outlined);
                    }
                    final node = _filteredNodes[index - 1];
                    final nodePath = _getNodePath(node);
                    final pathStr = _getPathString(nodePath);
                    return _buildTargetTile(
                      node.id,
                      node.name,
                      node.iconData,
                      type: node.type.name.toUpperCase(),
                      path: pathStr.isNotEmpty ? pathStr : null,
                    );
                  },
                );
              },
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveMove,
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Speichern & Verschieben'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetTile(String? id, String title, IconData icon, {String? type, String? path}) {
    final isSelected = _selectedNodeId == (id ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedNodeId = id ?? ''),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (type != null) Text(type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
                    if (path != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        path,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary.withAlpha(200),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
