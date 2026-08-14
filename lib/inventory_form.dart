import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'models.dart';
import 'scanner_screen.dart';
import 'package:pocketbase/pocketbase.dart';

class InventoryForm extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialPhotoUrl;
  final int? initialQuantity;
  final String? initialIcon;
  final String? initialLabelId;
  final bool showQuantity;
  final bool showIcons;
  final bool showQrScanner;
  final List<String>? availableIcons;
  final PocketBase pb;
  final Function(String name, int quantity, XFile? imageFile, String icon, String labelId) onSave;

  const InventoryForm({
    super.key,
    required this.title,
    this.initialName,
    this.initialPhotoUrl,
    this.initialQuantity,
    this.initialIcon,
    this.initialLabelId,
    this.showQuantity = false,
    this.showIcons = false,
    this.showQrScanner = false,
    this.availableIcons,
    required this.pb,
    required this.onSave,
  });

  @override
  State<InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends State<InventoryForm> {
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late String _selectedIcon;
  late String _currentLabelId;
  XFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _quantityController = TextEditingController(text: (widget.initialQuantity ?? 1).toString());
    _selectedIcon = widget.initialIcon ?? (widget.availableIcons?.first ?? 'inventory_2');
    _currentLabelId = widget.initialLabelId ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSourceOption(Icons.photo_camera, 'Kamera', ImageSource.camera),
              _buildSourceOption(Icons.photo_library, 'Galerie', ImageSource.gallery),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption(IconData icon, String label, ImageSource source) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        final picker = ImagePicker();
        final file = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
        if (file != null) setState(() => _pickedFile = file);
      },
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Foto-Sektion
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withAlpha(40)),
                  ),
                  child: _pickedFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: kIsWeb ? Image.network(_pickedFile!.path, fit: BoxFit.cover) : Image.file(io.File(_pickedFile!.path), fit: BoxFit.cover),
                        )
                      : (widget.initialPhotoUrl != null && widget.initialPhotoUrl!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.network(widget.initialPhotoUrl!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(height: 8),
                                const Text('Foto hinzufügen', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Name
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.label_outline),
                  filled: true,
                  fillColor: isDark ? Colors.white.withAlpha(5) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              
              if (widget.showQuantity) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Anzahl',
                    prefixIcon: const Icon(Icons.numbers),
                    filled: true,
                    fillColor: isDark ? Colors.white.withAlpha(5) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ],
              
              if (widget.showQrScanner) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: isDark ? Colors.white.withAlpha(5) : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    dense: true,
                    title: const Text('QR-Code'),
                    subtitle: Text(_currentLabelId.isEmpty ? 'Automatisch' : 'ID: $_currentLabelId', overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: Icon(_currentLabelId.isEmpty ? Icons.qr_code_scanner : Icons.clear),
                      onPressed: () async {
                        if (_currentLabelId.isEmpty) {
                          final scannedId = await Navigator.push(context, MaterialPageRoute(builder: (context) => ScannerScreen(pb: widget.pb, isAssigningMode: true)));
                          if (scannedId != null) setState(() => _currentLabelId = scannedId);
                        } else {
                          setState(() => _currentLabelId = '');
                        }
                      },
                    ),
                  ),
                ),
              ],
              
              if (widget.showIcons && widget.availableIcons != null) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.availableIcons!.map((key) => GestureDetector(
                    onTap: () => setState(() => _selectedIcon = key),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedIcon == key ? Theme.of(context).colorScheme.primary : (isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(20)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(iconMapping[key], size: 22, color: _selectedIcon == key ? Colors.white : (isDark ? Colors.white70 : Colors.black54)),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              widget.onSave(
                _nameController.text.trim(),
                int.tryParse(_quantityController.text) ?? 1,
                _pickedFile,
                _selectedIcon,
                _currentLabelId,
              );
            }
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
