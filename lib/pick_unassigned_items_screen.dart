import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'ui_components.dart';

class PickUnassignedItemsScreen extends StatefulWidget {
  final PocketBase pb;
  final StorageNode targetNode;

  const PickUnassignedItemsScreen({
    super.key, 
    required this.pb, 
    required this.targetNode
  });

  @override
  State<PickUnassignedItemsScreen> createState() => _PickUnassignedItemsScreenState();
}

class _PickUnassignedItemsScreenState extends State<PickUnassignedItemsScreen> {
  late Future<List<Item>> _itemsFuture;
  final Set<String> _selectedItemIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _refreshItems();
  }

  void _refreshItems() {
    _itemsFuture = _fetchUnassignedItems();
    setState(() {});
  }

  Future<List<Item>> _fetchUnassignedItems() async {
    final records = await widget.pb.collection('items').getFullList(
      filter: 'node = ""',
      sort: '-created',
    );
    return records.map((r) => Item.fromRecord(r)).toList();
  }

  Future<void> _addSelectedItems() async {
    if (_selectedItemIds.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      for (final id in _selectedItemIds) {
        await widget.pb.collection('items').update(id, body: {
          'node': widget.targetNode.id,
        });
      }
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Artikel einsortieren', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('In: ${widget.targetNode.name}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
          ],
        ),
      ),
      body: FutureBuilder<List<Item>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Alle Artikel sind bereits einsortiert.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = _selectedItemIds.contains(item.id);
              return InventoryListTile(
                entity: item,
                pb: widget.pb,
                trailingOverride: Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedItemIds.add(item.id);
                      } else {
                        _selectedItemIds.remove(item.id);
                      }
                    });
                  },
                ),
                onTapOverride: () {
                  setState(() {
                    if (isSelected) {
                      _selectedItemIds.remove(item.id);
                    } else {
                      _selectedItemIds.add(item.id);
                    }
                  });
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: FilledButton.icon(
          onPressed: (_selectedItemIds.isEmpty || _isSaving) ? null : _addSelectedItems,
          icon: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check),
          label: Text('${_selectedItemIds.length} Artikel einsortieren'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
      ),
    );
  }

}
