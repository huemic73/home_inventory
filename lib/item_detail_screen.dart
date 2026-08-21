import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'qr_display_screen.dart';
import 'ui_components.dart';

class ItemDetailScreen extends StatefulWidget {
  final Item item;
  final PocketBase pb;

  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.pb,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late String _currentPhoto;
  late String _currentName;
  late String _currentDescription;
  late int _currentQuantity;
  RecordModel? _currentRecord;

  @override
  void initState() {
    super.initState();
    _currentPhoto = widget.item.photo;
    _currentName = widget.item.name;
    _currentDescription = widget.item.description;
    _currentQuantity = widget.item.quantity;
    _currentRecord = widget.item.record;
  }

  List<StorageNode> _extractBreadcrumbs(RecordModel? itemRecord) {
    if (itemRecord == null) return [];

    final List<StorageNode> path = [];
    dynamic current = itemRecord.data['expand']?['node'];

    // Durchläuft alle Ebenen von innen nach außen
    while (current is Map<String, dynamic>) {
      path.add(StorageNode.fromRecord(RecordModel(current)));
      current = current['expand']?['parent'];
    }

    // Umkehren: Vom obersten Raum (z. B. "1. OG") bis zum konkreten Ort ("Rollcontainer")
    return path.reversed.toList();
  }

  String _getImageUrl() {
    if (_currentPhoto.isEmpty || _currentRecord == null) {
      return '';
    }
    return widget.pb.files.getUrl(_currentRecord!, _currentPhoto).toString();
  }

  List<Tag> _getTags() {
    if (_currentRecord == null) return [];
    final expandedTags = _currentRecord!.expand['tags'] ?? [];
    return expandedTags
        .map((r) => Tag.fromRecord(r))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getImageUrl();
    final breadcrumbs = _extractBreadcrumbs(_currentRecord);
    final tags = _getTags();

    return InventoryPageLayout(
      title: _currentName,
      subtitle: breadcrumbs.isNotEmpty ? breadcrumbs.last.name : null,
      imageUrl: imageUrl,
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_2),
          tooltip: 'QR-Code',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => QrDisplayScreen(item: widget.item)),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Optionen',
          onSelected: (value) {
            if (value == 'edit') {
              _showEditItemDialog();
            } else if (value == 'delete') {
              _showDeleteConfirmDialog();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
            const PopupMenuItem(value: 'delete', child: Text('Löschen')),
          ],
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Column(
                  children: [
                    _buildInfoRow(context, 'Name', _currentName, Icons.label_outline),
                    if (tags.isNotEmpty) ...[
                      const Divider(height: 32),
                      _buildTagsRow(context, tags),
                    ],
                    if (_currentDescription.isNotEmpty) ...[
                      const Divider(height: 32),
                      _buildInfoRow(context, 'Beschreibung', _currentDescription, Icons.description_outlined),
                    ],
                    const Divider(height: 32),
                    _buildInfoRow(context, 'Anzahl', '$_currentQuantity Stück', Icons.numbers),
                    const Divider(height: 32),
                    // Standort-Zeile: Entweder als formatierten Pfad oder als Breadcrumb-Chips
                    _buildLocationRow(context, breadcrumbs),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsRow(BuildContext context, List<Tag> tags) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.tag, size: 20, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tags',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary.withAlpha(150),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tag.colorData.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tag.colorData.withAlpha(50)),
                  ),
                  child: Text(
                    tag.name,
                    style: TextStyle(
                      color: tag.colorData,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(BuildContext context, List<StorageNode> path) {
    if (path.isEmpty) {
      return _buildInfoRow(context, 'Standort', 'Ohne Zuordnung', Icons.location_on_outlined);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(10),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.location_on_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Standort',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary.withAlpha(150),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (int i = 0; i < path.length; i++) ...[
                    Text(
                      path[i].name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: i == path.length - 1 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (i < path.length - 1)
                      const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditItemDialog() {
    showDialog(
      context: context,
      builder: (context) => InventoryForm(
        title: 'Gegenstand bearbeiten',
        initialName: _currentName,
        initialDescription: _currentDescription,
        initialQuantity: _currentQuantity,
        initialPhotoUrl: _currentPhoto.isNotEmpty && _currentRecord != null
            ? widget.pb.files.getUrl(_currentRecord!, _currentPhoto).toString() 
            : null,
        initialTagIds: _currentRecord?.getListValue<String>('tags'),
        showQuantity: true,
        showTagSelector: true,
        showDescription: true,
        pb: widget.pb,
        onSave: (String n, String d, int q, XFile? f, String i, String l, NodeType t, List<String> ts, bool deleteImage) async {
          final Map<String, dynamic> body = {
            'name': n,
            'description': d,
            'quantity': q,
            'tags': ts,
          };

          if (deleteImage) {
            body['photo'] = null;
          }

          List<http.MultipartFile> files = [];
          if (f != null) {
            final bytes = await f.readAsBytes();
            files.add(http.MultipartFile.fromBytes('photo', bytes, filename: f.name));
          }

          try {
            final updatedRecord = await widget.pb.collection('items').update(
              widget.item.id,
              body: body,
              files: files,
              expand: 'node,tags',
            );
            
            setState(() {
              _currentName = n;
              _currentDescription = d;
              _currentQuantity = q;
              _currentPhoto = updatedRecord.getStringValue('photo');
              _currentRecord = updatedRecord;
            });
            
            if (context.mounted) {
              Navigator.pop(context);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
            }
          }
        },
      ),
    );
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gegenstand löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await widget.pb.collection('items').delete(widget.item.id);
              if (mounted) { 
                nav.pop(); 
                nav.pop(true); 
              }
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(10), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(150), fontSize: 11, fontWeight: FontWeight.w600)),
              Text(
                value, 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

}
