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
  final StorageLocation? storageLocation; // Optionaler Filter

  const ContainerListScreen({super.key, required this.pb, required this.room, this.storageLocation});

  @override
  State<ContainerListScreen> createState() => _ContainerListScreenState();
}

class _ContainerListScreenState extends State<ContainerListScreen> {
  late Future<Map<String, dynamic>> _dataFuture;
  Map<String, int> _containerItemCounts = {};
  bool _onlyWithItems = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    _dataFuture = _fetchData();
    setState(() {});
  }

  Future<Map<String, dynamic>> _fetchData() async {
    // 1. Ablageorte im Raum laden (nur wenn wir nicht schon in einem sind)
    List<StorageLocation> locations = [];
    if (widget.storageLocation == null) {
      final locRecords = await widget.pb.collection('storage_locations').getFullList(
        filter: 'room = "${widget.room.id}"',
        sort: 'name',
      );
      locations = locRecords.map((r) => StorageLocation.fromRecord(r)).toList();
    }

    // 2. Container laden
    String filter = 'room = "${widget.room.id}"';
    if (widget.storageLocation != null) {
      filter += ' && storage_location = "${widget.storageLocation!.id}"';
    } else {
      // Wenn wir auf Raum-Ebene sind, zeigen wir nur Container ohne Ablageort direkt an?
      // Oder alle? Ich schlage vor: Nur die ohne Ablageort, um Duplikate zu vermeiden.
      filter += ' && storage_location = ""';
    }

    final contRecords = await widget.pb.collection('containers').getFullList(
      filter: filter,
      sort: 'name',
    );
    final containers = contRecords.map((r) => InventoryContainer.fromRecord(r)).toList();
    
    // 3. Item Counts
    final itemRecords = await widget.pb.collection('items').getFullList(fields: 'container');
    final Map<String, int> counts = {};
    for (var record in itemRecords) {
      final containerId = record.getStringValue('container');
      if (containerId.isNotEmpty) counts[containerId] = (counts[containerId] ?? 0) + 1;
    }
    
    if (mounted) setState(() => _containerItemCounts = counts);

    return {'locations': locations, 'containers': containers};
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.storageLocation?.name ?? widget.room.name;
    final subtitle = widget.storageLocation != null ? 'In: ${widget.room.name}' : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Theme.of(context).colorScheme.primary.withAlpha(20), Theme.of(context).scaffoldBackgroundColor],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120, pinned: true, backgroundColor: Colors.transparent, elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                title: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87)),
                    if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary.withAlpha(150))),
                  ],
                ),
              ),
              actions: [
                IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
                const SizedBox(width: 16),
              ],
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                
                final locations = snapshot.data!['locations'] as List<StorageLocation>;
                var containers = snapshot.data!['containers'] as List<InventoryContainer>;

                if (_onlyWithItems) {
                  containers = containers.where((c) => (_containerItemCounts[c.id] ?? 0) > 0).toList();
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (locations.isNotEmpty) ...[
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Ablageorte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        _buildLocationsGrid(locations),
                        const SizedBox(height: 24),
                      ],
                      if (containers.isNotEmpty || widget.storageLocation != null) ...[
                        Text(widget.storageLocation != null ? 'Container hier' : 'Direkt im Raum', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        _buildContainersGrid(containers),
                      ],
                      if (locations.isEmpty && containers.isEmpty) 
                        const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('Hier ist noch alles leer.'))),
                    ]),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      floatingActionButton: _buildFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLocationsGrid(List<StorageLocation> locations) {
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisExtent: 100, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: locations.length,
      itemBuilder: (context, index) => _buildLocationCard(locations[index]),
    );
  }

  Widget _buildLocationCard(StorageLocation loc) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24), 
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)]
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ContainerListScreen(pb: widget.pb, room: widget.room, storageLocation: loc))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(loc.iconData, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.name, 
                  style: const TextStyle(fontWeight: FontWeight.bold), 
                  overflow: TextOverflow.ellipsis
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (val) {
                  if (val == 'edit') _showAddLocationDialog(context, location: loc);
                  if (val == 'delete') _showDeleteLocationConfirmDialog(context, loc);
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
    );
  }

  Widget _buildContainersGrid(List<InventoryContainer> containers) {
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 450, mainAxisExtent: 130, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: containers.length,
      itemBuilder: (context, index) => _buildContainerCard(context, containers[index]),
    );
  }

  Widget _buildContainerCard(BuildContext context, InventoryContainer container) {
    final itemCount = _containerItemCounts[container.id] ?? 0;
    String imageUrl = container.photo.isNotEmpty ? widget.pb.files.getUrl(container.record, container.photo).toString() : '';

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => ItemListScreen(pb: widget.pb, container: container, room: widget.room)));
            _refreshData();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(10), borderRadius: BorderRadius.circular(20)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: imageUrl.isNotEmpty 
                      ? Image.network(imageUrl, fit: BoxFit.cover) 
                      : Icon(container.iconData, color: Theme.of(context).colorScheme.primary, size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(container.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('$itemCount Artikel', style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(150), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (val) {
                    if (val == 'edit') _showAddContainerDialog(context, container: container);
                    if (val == 'delete') _showDeleteConfirmDialog(context, container);
                  },
                  itemBuilder: (context) => [const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')), const PopupMenuItem(value: 'delete', child: Text('Löschen'))],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.storageLocation == null)
          FloatingActionButton.extended(
            heroTag: 'add_loc',
            onPressed: () => _showAddLocationDialog(context),
            icon: const Icon(Icons.shelves),
            label: const Text('Ort'),
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        const SizedBox(width: 12),
        FloatingActionButton.extended(
          heroTag: 'add_cont',
          onPressed: () => _showAddContainerDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Container'),
        ),
      ],
    );
  }

  void _showAddLocationDialog(BuildContext context, {StorageLocation? location}) {
    final controller = TextEditingController(text: location?.name);
    String selectedIcon = location?.iconName ?? 'shelves';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(location == null ? 'Neuer Ablageort' : 'Ort bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name (z.B. Regal A)', border: OutlineInputBorder())),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: ['shelves', 'door_sliding', 'home_repair_service'].map((key) => GestureDetector(
                  onTap: () => setState(() => selectedIcon = key),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: selectedIcon == key ? Theme.of(context).colorScheme.primary : Colors.grey.withAlpha(20), borderRadius: BorderRadius.circular(16)),
                    child: Icon(iconMapping[key], color: selectedIcon == key ? Colors.white : Colors.black54),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  final data = {'name': controller.text, 'icon': selectedIcon};
                  if (location == null) {
                    data['room'] = widget.room.id;
                    await widget.pb.collection('storage_locations').create(body: data);
                  } else {
                    await widget.pb.collection('storage_locations').update(location.id, body: data);
                  }
                  if (context.mounted) Navigator.pop(context);
                  _refreshData();
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteLocationConfirmDialog(BuildContext context, StorageLocation loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ort löschen?'),
        content: Text('Soll "${loc.name}" wirklich gelöscht werden? Die darin enthaltenen Container bleiben im Raum erhalten, verlieren aber ihren Platz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await widget.pb.collection('storage_locations').delete(loc.id);
              if (context.mounted) {
                nav.pop();
                _refreshData();
              }
            }, 
            child: const Text('Löschen', style: TextStyle(color: Colors.red))
          ),
        ],
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
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
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
                  const SizedBox(height: 16),
                  TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))))),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: iconMapping.entries.map((e) => GestureDetector(
                      onTap: () => setState(() => selectedIcon = e.key),
                      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: selectedIcon == e.key ? Theme.of(context).colorScheme.secondaryContainer : null, border: Border.all(color: selectedIcon == e.key ? Theme.of(context).colorScheme.secondary : Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                        child: Icon(e.value, size: 22),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  final Map<String, dynamic> data = {
                    'name': controller.text, 'icon': selectedIcon,
                    'labelId': currentLabelId.isEmpty ? null : currentLabelId,
                  };
                  if (widget.storageLocation != null) data['storage_location'] = widget.storageLocation!.id;

                  List<http.MultipartFile> files = [];
                  if (pickedFile != null) {
                    final bytes = await pickedFile!.readAsBytes();
                    files.add(http.MultipartFile.fromBytes('photo', bytes, filename: pickedFile!.name));
                  }
                  try {
                    if (container == null) {
                      data['room'] = widget.room.id;
                      await widget.pb.collection('containers').create(body: data, files: files);
                    } else {
                      await widget.pb.collection('containers').update(container.id, body: data, files: files);
                    }
                    if (context.mounted) Navigator.pop(context);
                    _refreshData();
                  } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
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
              if (context.mounted) { nav.pop(); _refreshData(); }
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
