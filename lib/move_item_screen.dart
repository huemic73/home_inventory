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
    _filteredNodes = List.from(_allNodes);
    return _allNodes;
  }

  void _filterList(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredNodes = _allNodes.where((node) {
        return node.name.toLowerCase().contains(_searchQuery);
      }).toList();
    });
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
                    return _buildTargetTile(node.id, node.name, node.iconData, type: node.type.name.toUpperCase());
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

  Widget _buildTargetTile(String? id, String title, IconData icon, {String? type}) {
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
