import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'move_item_screen.dart';
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
  late int _currentQuantity;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentPhoto = widget.item.photo;
    _currentName = widget.item.name;
    _currentQuantity = widget.item.quantity;
  }

  String _getImageUrl() {
    if (_currentPhoto.isEmpty || widget.item.record == null) {
      return '';
    }
    return widget.pb.files.getUrl(widget.item.record!, _currentPhoto).toString();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (image == null || widget.item.record == null) {
      return;
    }

    setState(() => _isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      final file = http.MultipartFile.fromBytes('photo', bytes, filename: image.name);
      
      final updatedRecord = await widget.pb.collection('items').update(
        widget.item.id,
        files: [file],
      );

      setState(() {
        _currentPhoto = updatedRecord.getStringValue('photo');
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getImageUrl();

    // Pfad berechnen
    String path = 'Ohne Zuordnung';
    final containerRecord = widget.item.record?.get<RecordModel?>('expand.container');
    if (containerRecord != null) {
      final roomName = containerRecord.get<RecordModel?>('expand.room')?.getStringValue('name') ?? 'Unbekannter Raum';
      final containerName = containerRecord.getStringValue('name');
      final locRecord = containerRecord.get<RecordModel?>('expand.storage_location');
      final locName = locRecord?.getStringValue('name');
      
      if (locName != null && locName.isNotEmpty) {
        path = '$roomName > $locName > $containerName';
      } else {
        path = '$roomName > $containerName';
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InventoryPageLayout(
      title: _currentName,
      subtitle: path,
      imageUrl: imageUrl,
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_2),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QrDisplayScreen(item: widget.item))),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(),
                  ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(context, 'Name', _currentName, Icons.label_outline),
                      const Divider(height: 32),
                      _buildInfoRow(context, 'Anzahl', '$_currentQuantity Stück', Icons.numbers),
                      const Divider(height: 32),
                      _buildInfoRow(context, 'Standort', path, Icons.location_on_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Aktionen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context, 
                        'Foto ändern', 
                        Icons.add_a_photo_outlined, 
                        () => _showImageSourceActionSheet(context)
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionButton(
                        context, 
                        'Verschieben', 
                        Icons.drive_file_move_outlined, 
                        () async {
                          final navigator = Navigator.of(context);
                          final result = await Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => MoveItemScreen(pb: widget.pb, item: widget.item))
                          );
                          if (result == true) {
                            navigator.pop(true); 
                          }
                        }
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withAlpha(10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(30)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showEditItemDialog() {
    showDialog(
      context: context,
      builder: (context) => InventoryForm(
        title: 'Gegenstand bearbeiten',
        initialName: _currentName,
        initialQuantity: _currentQuantity,
        initialPhotoUrl: _currentPhoto.isNotEmpty 
            ? widget.pb.files.getUrl(widget.item.record!, _currentPhoto).toString() 
            : null,
        showQuantity: true,
        pb: widget.pb,
        onSave: (name, quantity, imageFile, icon, labelId) async {
          final Map<String, dynamic> body = {
            'name': name,
            'quantity': quantity,
          };

          List<http.MultipartFile> files = [];
          if (imageFile != null) {
            if (kIsWeb) {
              final bytes = await imageFile.readAsBytes();
              files.add(http.MultipartFile.fromBytes('photo', bytes, filename: imageFile.name));
            } else {
              files.add(await http.MultipartFile.fromPath('photo', imageFile.path));
            }
          }

          try {
            final updatedRecord = await widget.pb.collection('items').update(
              widget.item.id,
              body: body,
              files: files,
            );
            
            setState(() {
              _currentName = name;
              _currentQuantity = quantity;
              _currentPhoto = updatedRecord.getStringValue('photo');
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
      crossAxisAlignment: CrossAxisAlignment.center, // Vertikale Ausrichtung
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(10), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded( // WICHTIG: Erlaubt der Spalte den restlichen Platz zu nutzen
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(150), fontSize: 11, fontWeight: FontWeight.w600)),
              Text(
                value, 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                softWrap: true, // Zeilenumbruch erlauben
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSourceOption(context, Icons.photo_camera, 'Kamera', ImageSource.camera),
              _buildSourceOption(context, Icons.photo_library, 'Galerie', ImageSource.gallery),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption(BuildContext context, IconData icon, String label, ImageSource source) {
    return InkWell(
      onTap: () { Navigator.pop(context); _pickAndUploadImage(source); },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(10), shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
