import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';

class MoveContainerScreen extends StatefulWidget {
  final PocketBase pb;
  final StorageNode node;

  const MoveContainerScreen({super.key, required this.pb, required this.node});

  @override
  State<MoveContainerScreen> createState() => _MoveContainerScreenState();
}

class _MoveContainerScreenState extends State<MoveContainerScreen> {
  late Future<List<StorageNode>> _potentialParentsFuture;
  List<StorageNode> _allPotentialParents = [];
  List<StorageNode> _filteredParents = [];
  String _searchQuery = '';
  String? _selectedParentId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _potentialParentsFuture = _fetchPotentialParents();
    _selectedParentId = widget.node.parentId;
  }

  Future<List<StorageNode>> _fetchPotentialParents() async {
    final records = await widget.pb.collection('nodes').getFullList(sort: 'name');
    final allNodes = records.map((r) => StorageNode.fromRecord(r)).toList();
    
    // Zirkelbezug-Check: Alle Nachkommen dieser Node finden
    final Set<String> descendants = {};
    void findDescendants(String parentId) {
      for (var node in allNodes) {
        if (node.parentId == parentId) {
          if (descendants.add(node.id)) {
            findDescendants(node.id);
          }
        }
      }
    }
    findDescendants(widget.node.id);

    // Typschutz anwenden + Zirkelbezug ausschließen
    _allPotentialParents = allNodes.where((potentialParent) {
      final isSelf = potentialParent.id == widget.node.id;
      final isDescendant = descendants.contains(potentialParent.id);
      return !isSelf && !isDescendant && widget.node.canBePlacedIn(potentialParent);
    }).toList();
    
    _filteredParents = List.from(_allPotentialParents);
    return _allPotentialParents;
  }

  void _filterList(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredParents = _allPotentialParents.where((node) {
        final matchesQuery = node.name.toLowerCase().contains(_searchQuery);
        return matchesQuery;
      }).toList();
    });
  }

  Future<void> _saveMove() async {
    setState(() => _isSaving = true);
    try {
      await widget.pb.collection('nodes').update(
        widget.node.id,
        body: {
          'parent': _selectedParentId ?? '',
        },
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
        title: const Text('Verschieben nach...', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Info-Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(30)))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Element:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(widget.node.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // Suchfeld
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Nach Ziel suchen (z.B. Reihe 1)...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: _filterList,
            ),
          ),

          // Liste der Ziele
          Expanded(
            child: FutureBuilder<List<StorageNode>>(
              future: _potentialParentsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                if (_filteredParents.isEmpty && _searchQuery.isNotEmpty) {
                  return const Center(child: Text('Kein passendes Ziel gefunden.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredParents.length + 1, // +1 für "Hauptebene"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildTargetTile(null, 'Hauptebene (kein Parent)', Icons.home_outlined);
                    }
                    final node = _filteredParents[index - 1];
                    return _buildTargetTile(node.id, node.name, node.iconData, type: node.type.name.toUpperCase());
                  },
                );
              },
            ),
          ),
          
          // Footer-Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveMove,
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Verschieben bestätigen'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetTile(String? id, String title, IconData icon, {String? type}) {
    final isSelected = _selectedParentId == (id ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedParentId = id ?? ''),
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
                    if (type != null) Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
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
