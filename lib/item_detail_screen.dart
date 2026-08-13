import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io' as io;
import 'models.dart';
import 'move_item_screen.dart';
import 'qr_display_screen.dart';

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getImageUrl();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                      : Container(
                          color: Theme.of(context).colorScheme.primary.withAlpha(50),
                          child: const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.white54),
                        ),
                  if (_isUploading)
                    Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
                  // Gradient Overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withAlpha(100), Colors.transparent, Colors.black.withAlpha(150)],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(_currentName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_2),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QrDisplayScreen(item: widget.item))),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') _showEditItemDialog();
                  else if (value == 'delete') _showDeleteConfirmDialog();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                  const PopupMenuItem(value: 'delete', child: Text('Löschen')),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(context, 'Name', _currentName, Icons.label_outline),
                        const Divider(height: 40),
                        _buildInfoRow(context, 'Anzahl', '$_currentQuantity Stück', Icons.numbers),
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
                            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => MoveItemScreen(pb: widget.pb, item: widget.item)));
                            if (result == true && mounted) Navigator.pop(context, true); 
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
      ),
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
    final nameController = TextEditingController(text: _currentName);
    final quantityController = TextEditingController(text: _currentQuantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text('Gegenstand bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))))),
            const SizedBox(height: 16),
            TextField(controller: quantityController, decoration: const InputDecoration(labelText: 'Anzahl', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newQuantity = int.tryParse(quantityController.text) ?? _currentQuantity;
              if (newName.isNotEmpty) {
                await widget.pb.collection('items').update(widget.item.id, body: {'name': newName, 'quantity': newQuantity});
                setState(() { _currentName = newName; _currentQuantity = newQuantity; });
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await widget.pb.collection('items').delete(widget.item.id);
              if (mounted) { nav.pop(); nav.pop(true); }
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(10), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(150), fontSize: 11, fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
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
