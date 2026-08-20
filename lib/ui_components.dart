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

/// Ein konsolidierter Action-Button, der ein Menü öffnet
class InventoryActionFab extends StatelessWidget {
  final List<InventoryAction> actions;
  final String heroTag;

  const InventoryActionFab({
    super.key, 
    required this.actions,
    this.heroTag = 'main_fab',
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: () => _showActionMenu(context),
      icon: const Icon(Icons.add),
      label: const Text('Hinzufügen', style: TextStyle(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Was möchtest du tun?', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
              const SizedBox(height: 16),
              ...actions.map((action) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: action.isPrimary 
                        ? Theme.of(context).colorScheme.primary.withAlpha(20)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    action.icon, 
                    color: action.isPrimary ? Theme.of(context).colorScheme.primary : null
                  ),
                ),
                title: Text(
                  action.label, 
                  style: TextStyle(
                    fontWeight: action.isPrimary ? FontWeight.bold : FontWeight.normal,
                    color: action.isPrimary ? Theme.of(context).colorScheme.primary : null,
                  )
                ),
                onTap: () {
                  Navigator.pop(context);
                  action.onTap();
                },
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const InventoryAction({
    required this.label, 
    required this.icon, 
    required this.onTap, 
    this.isPrimary = false
  });
}

/// Das Master-Layout für alle Übersichtsseiten (Räume, Orte, Container, Suche)
class InventoryPageLayout extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final List<Widget>? actions;
  final Widget? drawer;
  final List<Widget>? filterChips;
  final Widget? filterBar;
  final String? sectionTitle;
  final List<Widget> slivers;
  final Widget? floatingActionButton;
  final List<StorageNode>? breadcrumbs; // Neu: Pfad-Navigation
  final VoidCallback? onHomePressed;     // Neu: Schnell zurück zum Start

  const InventoryPageLayout({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.actions,
    this.drawer,
    this.filterChips,
    this.filterBar,
    this.sectionTitle,
    required this.slivers,
    this.floatingActionButton,
    this.breadcrumbs,
    this.onHomePressed,
  });

  double _calculateHeaderHeight(Widget? bar, List<Widget>? chips, String? title) {
    double h = 20.0;
    if (bar != null) h += 72.0;
    if (chips != null) h += 48.0;
    if (title != null) h += 30.0;
    if (bar != null && (chips != null || title != null)) h += 12.0;
    if (chips != null && title != null) h += 12.0;
    return h;
  }

  Widget _buildBreadcrumbs(BuildContext context, bool useWhite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      height: 20,
      child: ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: breadcrumbs!.length,
        separatorBuilder: (context, index) => Text(
          ' > ', 
          style: TextStyle(color: useWhite ? Colors.white38 : Colors.black26, fontSize: 10)
        ),
        itemBuilder: (context, index) {
          final node = breadcrumbs![index];
          final isLast = index == breadcrumbs!.length - 1;
          return GestureDetector(
            onTap: isLast ? null : () {
              final int popCount = breadcrumbs!.length - index - 1;
              for (int i = 0; i < popCount; i++) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              node.name,
              style: TextStyle(
                color: useWhite ? (isLast ? Colors.white : Colors.white70) : (isLast ? Colors.black87 : Colors.black54),
                fontSize: 10,
                fontWeight: isLast ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }

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
              expandedHeight: hasHeaderImage ? 250 : (breadcrumbs != null ? 165 : 140),
              pinned: true,
              elevation: 0,
              backgroundColor: isDark 
                  ? Colors.black26 
                  : (hasHeaderImage ? Theme.of(context).colorScheme.primary : Colors.transparent),
              foregroundColor: isDark || hasHeaderImage ? Colors.white : Colors.black87,
              leading: (breadcrumbs != null && breadcrumbs!.isNotEmpty)
                  ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))
                  : null,
              actions: [
                if (onHomePressed != null)
                  IconButton(icon: const Icon(Icons.home_outlined), onPressed: onHomePressed),
                ...?actions,
              ],
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
                    if (breadcrumbs != null && breadcrumbs!.isNotEmpty)
                      _buildBreadcrumbs(context, isDark || hasHeaderImage),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800, 
                        fontSize: 18, 
                        color: isDark || hasHeaderImage ? Colors.white : Colors.black87
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && (breadcrumbs == null || breadcrumbs!.isEmpty))
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 10, 
                          color: isDark || hasHeaderImage ? Colors.white70 : Colors.black54
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (filterChips != null || filterBar != null || sectionTitle != null)
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  isDark: isDark,
                  // Dynamische Höhenberechnung basierend auf den vorhandenen Elementen
                  height: _calculateHeaderHeight(filterBar, filterChips, sectionTitle),
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor.withAlpha(250),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (filterBar != null) ...[
                          filterBar!,
                          if (filterChips != null || sectionTitle != null) const SizedBox(height: 12),
                        ],
                        if (filterChips != null) ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: filterChips!,
                            ),
                          ),
                          if (sectionTitle != null) const SizedBox(height: 12),
                        ],
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

/// Generalisiertes Listen-Element für alles (Items, Container, etc.)
class InventoryListTile extends StatelessWidget {
  final InventoryEntity entity;
  final PocketBase pb;
  final VoidCallback? onRefresh;
  final List<Widget>? trailingActions;
  final Widget? trailingOverride;
  final VoidCallback? onTapOverride;

  const InventoryListTile({
    super.key, 
    required this.entity, 
    required this.pb,
    this.onRefresh,
    this.trailingActions,
    this.trailingOverride,
    this.onTapOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(15), 
            borderRadius: BorderRadius.circular(16)
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: (entity.photo?.isNotEmpty ?? false) && entity.record != null
                ? Image.network(pb.files.getUrl(entity.record!, entity.photo!).toString(), fit: BoxFit.cover) 
                : Icon(entity.icon, color: Theme.of(context).colorScheme.primary.withAlpha(150)),
          ),
        ),
        title: Text(entity.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entity.secondaryInfo, style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(200))),
            if (entity.tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: entity.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tag.colorData.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag.name,
                    style: TextStyle(color: tag.colorData, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
        trailing: trailingOverride ?? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingActions != null) ...trailingActions!,
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTapOverride ?? () => entity.getAction(context, pb, onRefresh: onRefresh)(),
      ),
    );
  }
}

/// Grid-Element für alles (Items, Container, etc.)
class InventoryCard extends StatelessWidget {
  final InventoryEntity entity;
  final PocketBase pb;
  final VoidCallback? onRefresh;
  final String? subtitleOverride;
  final Widget? popupMenu;

  const InventoryCard({
    super.key,
    required this.entity,
    required this.pb,
    this.onRefresh,
    this.subtitleOverride,
    this.popupMenu,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, 4))]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () => entity.getAction(context, pb, onRefresh: onRefresh)(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(16)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: (entity.photo?.isNotEmpty ?? false) && entity.record != null
                          ? Image.network(pb.files.getUrl(entity.record!, entity.photo!).toString(), fit: BoxFit.cover) 
                          : Icon(entity.icon, color: Theme.of(context).colorScheme.primary, size: 28),
                      ),
                    ),
                    if (popupMenu != null) popupMenu!,
                  ],
                ),
                const Spacer(),
                Text(
                  entity.name.isEmpty ? 'Unbenannt' : entity.name, 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitleOverride ?? entity.secondaryInfo, 
                  style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(180), fontWeight: FontWeight.w600, fontSize: 12)
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zentrales Formular-Objekt für alle Eingaben
class InventoryForm extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialPhotoUrl;
  final int? initialQuantity;
  final String? initialIcon;
  final String? initialLabelId;
  final NodeType? initialType;
  final List<String>? initialTagIds;
  final bool showQuantity;
  final bool showIcons;
  final bool showQrScanner;
  final bool showTypeSelector;
  final bool showTagSelector;
  final PocketBase pb;
  final Function(String name, int quantity, XFile? imageFile, String icon, String labelId, NodeType type, List<String> tagIds) onSave;

  const InventoryForm({
    super.key,
    required this.title,
    this.initialName,
    this.initialPhotoUrl,
    this.initialQuantity,
    this.initialIcon,
    this.initialLabelId,
    this.initialType,
    this.initialTagIds,
    this.showQuantity = false,
    this.showIcons = false,
    this.showQrScanner = false,
    this.showTypeSelector = false,
    this.showTagSelector = false,
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
  late NodeType _selectedType;
  late List<String> _selectedTagIds;
  List<Tag> _allTags = [];
  XFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _quantityController = TextEditingController(text: (widget.initialQuantity ?? 1).toString());
    _selectedIcon = widget.initialIcon ?? 'inventory_2';
    _currentLabelId = widget.initialLabelId ?? '';
    _selectedType = widget.initialType ?? NodeType.container;
    _selectedTagIds = List.from(widget.initialTagIds ?? []);
    if (widget.showTagSelector) {
      _fetchTags();
    }
  }

  Future<void> _fetchTags() async {
    try {
      final records = await widget.pb.collection('tags').getFullList(sort: 'name');
      setState(() {
        _allTags = records.map((r) => Tag.fromRecord(r)).toList();
      });
    } catch (e) {
      debugPrint('Fehler beim Laden der Tags: $e');
    }
  }

  Future<void> _createNewTag() async {
    final controller = TextEditingController();
    String selectedColorHex = '3F51B5'; // Default indigo

    final List<Map<String, String>> colorOptions = [
      {'name': 'Indigo', 'hex': '3F51B5'},
      {'name': 'Rot', 'hex': 'E53935'},
      {'name': 'Grün', 'hex': '43A047'},
      {'name': 'Orange', 'hex': 'FB8C00'},
      {'name': 'Türkis', 'hex': '00ACC1'},
      {'name': 'Lila', 'hex': '8E24AA'},
      {'name': 'Bernstein', 'hex': 'FFB300'},
      {'name': 'Blaugrau', 'hex': '546E7A'},
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Neuen Tag erstellen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Tag Name',
                  hintText: 'z.B. Camping, Werkzeug...',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Farbe wählen:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colorOptions.map((color) {
                  final isSelected = selectedColorHex == color['hex'];
                  final Color circleColor = Color(int.parse('FF${color['hex']}', radix: 16));
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColorHex = color['hex']!),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: circleColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          if (isSelected) 
                            BoxShadow(color: circleColor.withAlpha(100), blurRadius: 8, spreadRadius: 2)
                        ],
                      ),
                      child: isSelected 
                          ? const Icon(Icons.check, color: Colors.white, size: 20) 
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  try {
                    final record = await widget.pb.collection('tags').create(body: {
                      'name': controller.text.trim(),
                      'color': selectedColorHex,
                    });
                    final newTag = Tag.fromRecord(record);
                    setState(() {
                      _allTags.add(newTag);
                      _selectedTagIds.add(newTag.id);
                    });
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    debugPrint('Tag-Erstellung fehlgeschlagen: $e');
                  }
                }
              },
              child: const Text('Erstellen'),
            ),
          ],
        ),
      ),
    );
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
              if (widget.showTypeSelector) ...[
                DropdownButtonFormField<NodeType>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Typ des Elements',
                    filled: true,
                    fillColor: isDark ? Colors.white.withAlpha(5) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                  items: NodeType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.name.toUpperCase()))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedType = val!;
                      // Standard-Icon für diesen Typ setzen, falls das aktuelle nicht passt
                      final available = iconsByType[_selectedType] ?? [];
                      if (!available.contains(_selectedIcon)) {
                        _selectedIcon = available.first;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
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
              if (widget.showIcons) ...[
                const SizedBox(height: 32),
                Align(alignment: Alignment.centerLeft, child: Text('Symbol wählen', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54))),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft, 
                  child: Wrap(
                    spacing: 12, runSpacing: 12, 
                    children: (iconsByType[_selectedType] ?? []).map((key) => GestureDetector(
                      onTap: () => setState(() => _selectedIcon = key), 
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200), 
                        padding: const EdgeInsets.all(12), 
                        decoration: BoxDecoration(
                          color: _selectedIcon == key ? Theme.of(context).colorScheme.primary : (isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(20)), 
                          borderRadius: BorderRadius.circular(16), 
                          border: Border.all(color: _selectedIcon == key ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2)
                        ), 
                        child: Icon(iconMapping[key] ?? Icons.help_outline, size: 28, color: _selectedIcon == key ? Colors.white : (isDark ? Colors.white60 : Colors.black45))
                      )
                    )).toList()
                  )
                ),
              ],
              if (widget.showTagSelector) ...[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tags', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                    TextButton.icon(
                      onPressed: _createNewTag, 
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Neu', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allTags.map((tag) {
                      final isSelected = _selectedTagIds.contains(tag.id);
                      return GestureDetector(
                        onLongPress: () => _confirmDeleteTag(tag),
                        child: FilterChip(
                          label: Text(tag.name, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                          selected: isSelected,
                          selectedColor: tag.colorData,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedTagIds.add(tag.id);
                              } else {
                                _selectedTagIds.remove(tag.id);
                              }
                            });
                          },
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')), FilledButton(onPressed: () { if (_nameController.text.isNotEmpty) { widget.onSave(_nameController.text.trim(), int.tryParse(_quantityController.text) ?? 1, _pickedFile, _selectedIcon, _currentLabelId, _selectedType, _selectedTagIds); } }, style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: const Text('Speichern', style: TextStyle(fontWeight: FontWeight.bold)))],
    );
  }

  Future<void> _confirmDeleteTag(Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tag löschen?'),
        content: Text('Möchtest du den Tag "${tag.name}" wirklich systemweit löschen? Er wird von allen Artikeln entfernt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.pb.collection('tags').delete(tag.id);
        setState(() {
          _allTags.removeWhere((t) => t.id == tag.id);
          _selectedTagIds.remove(tag.id);
        });
      } catch (e) {
        debugPrint('Fehler beim Löschen des Tags: $e');
      }
    }
  }

  Widget _buildFormTextField({required TextEditingController controller, required String label, required IconData icon, required bool isDark, TextInputType keyboardType = TextInputType.text}) {
    return TextField(controller: controller, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54), filled: true, fillColor: isDark ? Colors.white.withAlpha(5) : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2))));
  }
}
