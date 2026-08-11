import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io' as io;
import 'models.dart';
import 'move_item_screen.dart';

import 'qr_display_screen.dart'; // Import für QR-Anzeige

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
    if (_currentPhoto.isEmpty || widget.item.record == null) return '';
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

    if (image == null || widget.item.record == null) return;

    setState(() => _isUploading = true);

    try {
      List<http.MultipartFile> files = [];
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        files.add(http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: image.name,
        ));
      } else {
        files.add(await http.MultipartFile.fromPath('photo', image.path));
      }
      
      final updatedRecord = await widget.pb.collection('items').update(
        widget.item.id,
        files: files,
      );

      setState(() {
        _currentPhoto = updatedRecord.getStringValue('photo');
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto erfolgreich hochgeladen!')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Upload: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getImageUrl();

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditItemDialog();
              } else if (value == 'delete') {
                _showDeleteConfirmDialog();
              } else if (value == 'qr') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QrDisplayScreen(item: widget.item),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
              const PopupMenuItem(value: 'qr', child: Text('QR-Code anzeigen')),
              const PopupMenuItem(value: 'delete', child: Text('Löschen')),
            ],
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800), // Maximale Breite für Desktop
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, size: 64),
                                ),
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey[100],
                                child: Icon(
                                  Icons.inventory_2,
                                  size: 80,
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                ),
                              ),
                        if (_isUploading)
                          Container(
                            color: Colors.black26,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildInfoRow(context, 'Name', _currentName, Icons.label_outline),
                        const Divider(height: 24),
                        _buildInfoRow(context, 'Anzahl', '$_currentQuantity Stück', Icons.numbers),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text('Aktionen', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isUploading ? null : () => _showImageSourceActionSheet(context),
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Foto'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MoveItemScreen(
                                pb: widget.pb,
                                item: widget.item,
                              ),
                            ),
                          );
                          if (result == true && mounted) {
                            Navigator.pop(context, true); 
                          }
                        },
                        icon: const Icon(Icons.drive_file_move),
                        label: const Text('Verschieben'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditItemDialog() {
    final nameController = TextEditingController(text: _currentName);
    final quantityController = TextEditingController(text: _currentQuantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gegenstand bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'Anzahl'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newQuantity = int.tryParse(quantityController.text) ?? _currentQuantity;
              
              if (newName.isNotEmpty) {
                await widget.pb.collection('items').update(widget.item.id, body: {
                  'name': newName,
                  'quantity': newQuantity,
                });
                setState(() {
                  _currentName = newName;
                  _currentQuantity = newQuantity;
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gegenstand löschen?'),
        content: Text('Möchtest du "$_currentName" wirklich unwiderruflich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await widget.pb.collection('items').delete(widget.item.id);
              if (mounted) {
                Navigator.pop(context); // Dialog schließen
                Navigator.pop(context, true); // Zurück zur Liste mit Refresh-Signal
              }
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ],
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
