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
    setState(() {
      _itemsFuture = _fetchUnassignedItems();
    });
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
      // Alle ausgewählten Items nacheinander aktualisieren
      for (final id in _selectedItemIds) {
        await widget.pb.collection('items').update(id, body: {
          'container': widget.targetContainer.id,
        });
      }

      if (mounted) {
        Navigator.pop(context, true); // Erfolg zurückgeben
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Verschieben: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Artikel hinzufügen'),
            Text(
              'In: ${widget.targetContainer.name}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
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
            return const Center(child: Text('Keine unzugeordneten Artikel gefunden.'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Wähle Artikel aus, die du in "${widget.targetContainer.name}" einsortieren möchtest:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _selectedItemIds.contains(item.id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(item.name),
                      subtitle: Text('${item.quantity} Stück'),
                      secondary: _buildLeading(item),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedItemIds.add(item.id);
                          } else {
                            _selectedItemIds.remove(item.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton.icon(
            onPressed: (_selectedItemIds.isEmpty || _isSaving) ? null : _addSelectedItems,
            icon: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text('${_selectedItemIds.length} Artikel einsortieren'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageUrl.isNotEmpty
            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
            : const Icon(Icons.inventory_2_outlined, size: 20),
      ),
    );
  }
}
