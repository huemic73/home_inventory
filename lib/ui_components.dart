import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'models.dart';
import 'scanner_screen.dart';
import 'package:pocketbase/pocketbase.dart';

/// Zentrales Floating Action Button Objekt
class StandardFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String? heroTag;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const StandardFab({
    super.key,
    required this.label,
    this.icon = Icons.add,
    required this.onPressed,
    this.heroTag,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: backgroundColor ?? (isDark ? const Color(0xFF9FA8DA) : Theme.of(context).colorScheme.primary),
      foregroundColor: foregroundColor ?? (isDark ? const Color(0xFF1A1C1E) : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
    );
  }
}

/// Das Master-Layout für alle Übersichtsseiten (Räume, Orte, Container, Suche)
class InventoryPageLayout extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final List<Widget>? actions;
  final Widget? drawer;
  final List<Widget>? filterChips;
  final String? sectionTitle;
  final List<Widget> slivers; // Zwingend erforderlich
  final Widget? floatingActionButton;

  const InventoryPageLayout({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.actions,
    this.drawer,
    this.filterChips,
    this.sectionTitle,
    required this.slivers,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasHeaderImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Scaffold(
      drawer: drawer,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withAlpha(isDark ? 40 : 20),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: hasHeaderImage ? 250 : 140,
              pinned: true,
              elevation: 0,
              backgroundColor: isDark ? Colors.black26 : Colors.transparent,
              foregroundColor: Colors.white,
              actions: actions,
              flexibleSpace: FlexibleSpaceBar(
                background: hasHeaderImage 
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(imageUrl!, fit: BoxFit.cover),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black54, Colors.transparent, Colors.black87],
                              ),
                            ),
                          ),
                        ],
                      )
                    : null,
                titlePadding: const EdgeInsetsDirectional.only(start: 64, bottom: 16, end: 16),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ),
            if (filterChips != null || sectionTitle != null)
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  isDark: isDark,
                  height: (filterChips != null && sectionTitle != null) ? 120 : 80,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor.withAlpha(250),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (filterChips != null)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: filterChips!,
                            ),
                          ),
                        if (filterChips != null && sectionTitle != null) const SizedBox(height: 12),
                        if (sectionTitle != null)
                          Text(
                            sectionTitle!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ...slivers,
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final bool isDark;
  final double height;
  _StickyHeaderDelegate({required this.child, required this.isDark, required this.height});
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [if (shrinkOffset > 0) BoxShadow(color: Colors.black.withAlpha(isDark ? 40 : 10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
  @override
  double get maxExtent => height;
  @override
  double get minExtent => height;
  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) => height != oldDelegate.height;
}

/// Zentrales Formular-Objekt für alle Eingaben
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
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, minWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200, width: double.infinity,
                  decoration: BoxDecoration(color: isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(20), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withAlpha(40))),
                  child: _pickedFile != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(24), child: kIsWeb ? Image.network(_pickedFile!.path, fit: BoxFit.cover) : Image.file(io.File(_pickedFile!.path), fit: BoxFit.cover))
                      : (widget.initialPhotoUrl != null && widget.initialPhotoUrl!.isNotEmpty)
                          ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(widget.initialPhotoUrl!, fit: BoxFit.cover))
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(isDark ? 30 : 10), shape: BoxShape.circle), child: Icon(Icons.add_a_photo_outlined, color: Theme.of(context).colorScheme.primary)), const SizedBox(height: 12), Text('Foto hinzufügen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary.withAlpha(200)))]),
                ),
              ),
              const SizedBox(height: 32),
              _buildFormTextField(controller: _nameController, label: 'Name', icon: Icons.label_outline, isDark: isDark),
              if (widget.showQuantity) ...[const SizedBox(height: 16), _buildFormTextField(controller: _quantityController, label: 'Anzahl', icon: Icons.numbers, isDark: isDark, keyboardType: TextInputType.number)],
              if (widget.showQrScanner) ...[
                const SizedBox(height: 16),
                Card(elevation: 0, color: isDark ? Colors.white.withAlpha(5) : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: ListTile(dense: true, leading: Icon(Icons.qr_code_2, color: isDark ? Colors.white70 : Colors.black54), title: const Text('QR-Code Scanner'), subtitle: Text(_currentLabelId.isEmpty ? 'Automatisch generieren' : 'Manuelle ID: $_currentLabelId', overflow: TextOverflow.ellipsis),
                    trailing: IconButton(icon: Icon(_currentLabelId.isEmpty ? Icons.qr_code_scanner : Icons.clear, color: Theme.of(context).colorScheme.primary),
                      onPressed: () async {
                        if (_currentLabelId.isEmpty) {
                          final scannedId = await Navigator.push(context, MaterialPageRoute(builder: (context) => ScannerScreen(pb: widget.pb, isAssigningMode: true)));
                          if (scannedId != null) setState(() => _currentLabelId = scannedId);
                        } else { setState(() => _currentLabelId = ''); }
                      },
                    ),
                  ),
                ),
              ],
              if (widget.showIcons && widget.availableIcons != null) ...[
                const SizedBox(height: 32),
                Align(alignment: Alignment.centerLeft, child: Text('Symbol wählen', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54))),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 12, runSpacing: 12, children: widget.availableIcons!.map((key) => GestureDetector(onTap: () => setState(() => _selectedIcon = key), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _selectedIcon == key ? Theme.of(context).colorScheme.primary : (isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(20)), borderRadius: BorderRadius.circular(16), border: Border.all(color: _selectedIcon == key ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2)), child: Icon(iconMapping[key], size: 28, color: _selectedIcon == key ? Colors.white : (isDark ? Colors.white60 : Colors.black45))))).toList())),
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')), FilledButton(onPressed: () { if (_nameController.text.isNotEmpty) { widget.onSave(_nameController.text.trim(), int.tryParse(_quantityController.text) ?? 1, _pickedFile, _selectedIcon, _currentLabelId); } }, style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: const Text('Speichern', style: TextStyle(fontWeight: FontWeight.bold)))],
    );
  }

  Widget _buildFormTextField({required TextEditingController controller, required String label, required IconData icon, required bool isDark, TextInputType keyboardType = TextInputType.text}) {
    return TextField(controller: controller, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54), filled: true, fillColor: isDark ? Colors.white.withAlpha(5) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2))));
  }
}
