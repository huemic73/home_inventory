import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io' as io;
import 'models.dart';
import 'item_list_screen.dart';
import 'scanner_screen.dart';

class ContainerListScreen extends StatefulWidget {
  final PocketBase pb;
  final Room room;

  const ContainerListScreen({super.key, required this.pb, required this.room});

  @override
  State<ContainerListScreen> createState() => _ContainerListScreenState();
}

class _ContainerListScreenState extends State<ContainerListScreen> {
  late Future<List<InventoryContainer>> _containersFuture;
  Map<String, int> _containerItemCounts = {};
  bool _onlyWithItems = false;

  @override
  void initState() {
    super.initState();
    _refreshContainers();
  }

  void _refreshContainers() {
    _containersFuture = _fetchContainers();
    setState(() {});
  }

  Future<List<InventoryContainer>> _fetchContainers() async {
    final records = await widget.pb.collection('containers').getFullList(
      filter: 'room = "${widget.room.id}"',
      sort: 'name',
    );
    final containers = records.map((r) => InventoryContainer.fromRecord(r)).toList();
    
    final itemRecords = await widget.pb.collection('items').getFullList(fields: 'container');
    final Map<String, int> counts = {};
    for (var record in itemRecords) {
      final containerId = record.getStringValue('container');
      if (containerId.isNotEmpty) {
        counts[containerId] = (counts[containerId] ?? 0) + 1;
      }
    }
    
    if (mounted) {
      setState(() {
        _containerItemCounts = counts;
      });
    }

    return containers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withAlpha(20),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                title: Text(
                  widget.room.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                  onPressed: _refreshContainers,
                ),
                const SizedBox(width: 16),
              ],
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Alle Container'),
                      selected: !_onlyWithItems,
                      onSelected: (val) => setState(() => _onlyWithItems = false),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      showCheckmark: false,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Nur mit Artikeln'),
                      selected: _onlyWithItems,
                      onSelected: (val) => setState(() => _onlyWithItems = true),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      showCheckmark: false,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              sliver: FutureBuilder<List<InventoryContainer>>(
                future: _containersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                  }
                  var containers = snapshot.data ?? [];
                  if (_onlyWithItems) {
                    containers = containers.where((c) => (_containerItemCounts[c.id] ?? 0) > 0).toList();
                  }

                  if (containers.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(_onlyWithItems ? 'Keine vollen Container.' : 'Noch keine Container hier.'),
                        ),
                      ),
                    );
                  }

                  return SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 450,
                      mainAxisExtent: 140, // Genug Platz für Foto + Info
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildContainerCard(context, containers[index]),
                      childCount: containers.length,
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddContainerDialog(context),
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildContainerCard(BuildContext context, InventoryContainer container) {
    final itemCount = _containerItemCounts[container.id] ?? 0;
    String imageUrl = '';
    if (container.photo.isNotEmpty) {
      imageUrl = widget.pb.files.getUrl(container.record, container.photo).toString();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ItemListScreen(pb: widget.pb, container: container, room: widget.room)),
            );
            _refreshContainers();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Das neue Foto-Feld (ersetzt das Symbol wenn Bild da ist)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(container.iconData, color: Theme.of(context).colorScheme.primary))
                        : Icon(container.iconData, color: Theme.of(context).colorScheme.primary, size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(container.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer.withAlpha(100), borderRadius: BorderRadius.circular(20)),
                        child: Text('$itemCount Artikel', style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (val) {
                    if (val == 'edit') _showAddContainerDialog(context, container: container);
                    if (val == 'delete') _showDeleteConfirmDialog(context, container);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                    const PopupMenuItem(value: 'delete', child: Text('Löschen')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddContainerDialog(BuildContext context, {InventoryContainer? container}) {
    final controller = TextEditingController(text: container?.name);
    String selectedIcon = container?.iconName ?? 'inventory_2';
    String currentLabelId = container?.labelId ?? '';
    XFile? pickedFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: Text(container == null ? 'Neuer Container' : 'Bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                      builder: (bottomSheetContext) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildSourceOption(context, Icons.photo_camera, 'Kamera', () async {
                                Navigator.pop(bottomSheetContext);
                                final picker = ImagePicker();
                                final file = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
                                if (file != null) setState(() => pickedFile = file);
                              }),
                              _buildSourceOption(context, Icons.photo_library, 'Galerie', () async {
                                Navigator.pop(bottomSheetContext);
                                final picker = ImagePicker();
                                final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
                                if (file != null) setState(() => pickedFile = file);
                              }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 140, width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey.withAlpha(20), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.withAlpha(40))),
                    child: pickedFile != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(24), child: kIsWeb ? Image.network(pickedFile!.path, fit: BoxFit.cover) : Image.file(io.File(pickedFile!.path), fit: BoxFit.cover))
                        : (container?.photo.isNotEmpty == true && pickedFile == null)
                            ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(widget.pb.files.getUrl(container!.record, container.photo).toString(), fit: BoxFit.cover))
                            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Theme.of(context).colorScheme.primary), const Text('Foto hinzufügen', style: TextStyle(fontSize: 12))]),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))))),
                const SizedBox(height: 16),
                Card(
                  elevation: 0, color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(dense: true, title: const Text('QR-Code'), subtitle: Text(currentLabelId.isEmpty ? 'Automatisch' : 'ID: $currentLabelId', overflow: TextOverflow.ellipsis),
                    trailing: IconButton(icon: Icon(currentLabelId.isEmpty ? Icons.qr_code_scanner : Icons.clear),
                      onPressed: () async {
                        if (currentLabelId.isEmpty) {
                          final scannedId = await Navigator.push(context, MaterialPageRoute(builder: (context) => ScannerScreen(pb: widget.pb, isAssigningMode: true)));
                          if (scannedId != null) setState(() => currentLabelId = scannedId);
                        } else { setState(() => currentLabelId = ''); }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(spacing: 8, runSpacing: 8, children: iconMapping.entries.map((e) => GestureDetector(
                    onTap: () => setState(() => selectedIcon = e.key),
                    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: selectedIcon == e.key ? Theme.of(context).colorScheme.primary : Colors.grey.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                      child: Icon(e.value, size: 20, color: selectedIcon == e.key ? Colors.white : Colors.black54),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  final Map<String, dynamic> data = {
                    'name': controller.text, 
                    'icon': selectedIcon,
                    'labelId': currentLabelId.isEmpty ? null : currentLabelId,
                  };

                  List<http.MultipartFile> files = [];
                  if (pickedFile != null) {
                    if (kIsWeb) {
                      final bytes = await pickedFile!.readAsBytes();
                      files.add(http.MultipartFile.fromBytes(
                        'photo', 
                        bytes, 
                        filename: pickedFile!.name
                      ));
                    } else {
                      files.add(await http.MultipartFile.fromPath(
                        'photo', 
                        pickedFile!.path
                      ));
                    }
                  }

                  try {
                    if (container == null) {
                      data['room'] = widget.room.id;
                      await widget.pb.collection('containers').create(
                        body: data, 
                        files: files
                      );
                    } else {
                      await widget.pb.collection('containers').update(
                        container.id, 
                        body: data, 
                        files: files
                      );
                    }
                    if (context.mounted) Navigator.pop(context);
                    _refreshContainers();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Speicherfehler: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, InventoryContainer container) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Löschen?'), actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(onPressed: () async {
              final nav = Navigator.of(context);
              await widget.pb.collection('containers').delete(container.id);
              if (context.mounted) { nav.pop(); _refreshContainers(); }
            }, child: const Text('Löschen', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildSourceOption(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24),
      child: Padding(padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(10), shape: BoxShape.circle), child: Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
