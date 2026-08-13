import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';

class PickUnassignedItemsScreen extends StatefulWidget {
  final PocketBase pb;
  final InventoryContainer targetContainer;

  const PickUnassignedItemsScreen({
    super.key, 
    required this.pb, 
    required this.targetContainer
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
      filter: 'container = ""',
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
          'container': widget.targetContainer.id,
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
            Text('In: ${widget.targetContainer.name}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withAlpha(100) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: CheckboxListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    value: isSelected,
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${item.quantity} Stück'),
                    secondary: _buildLeading(item),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) _selectedItemIds.add(item.id);
                        else _selectedItemIds.remove(item.id);
                      });
                    },
                  ),
                ),
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

  Widget _buildLeading(Item item) {
    String imageUrl = '';
    if (item.photo.isNotEmpty && item.record != null) {
      imageUrl = widget.pb.files.getUrl(item.record!, item.photo).toString();
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl.isNotEmpty
            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
            : const Icon(Icons.inventory_2_outlined, size: 20),
      ),
    );
  }
}
