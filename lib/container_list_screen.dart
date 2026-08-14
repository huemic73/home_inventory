import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'item_list_screen.dart';
import 'move_container_screen.dart';
import 'ui_components.dart';

class ContainerListScreen extends StatefulWidget {
  final PocketBase pb;
  final Room room;
  final StorageLocation? storageLocation;

  const ContainerListScreen({super.key, required this.pb, required this.room, this.storageLocation});

  @override
  State<ContainerListScreen> createState() => _ContainerListScreenState();
}

class _ContainerListScreenState extends State<ContainerListScreen> {
  late Future<Map<String, dynamic>> _dataFuture;
  Map<String, int> _containerItemCounts = {};
  Map<String, int> _locationContainerCounts = {};
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
    List<StorageLocation> locations = [];
    if (widget.storageLocation == null) {
      final locRecords = await widget.pb.collection('storage_locations').getFullList(
        filter: 'room = "${widget.room.id}"',
        sort: 'name',
      );
      locations = locRecords.map((r) => StorageLocation.fromRecord(r)).toList();
    }

    String filter = 'room = "${widget.room.id}"';
    if (widget.storageLocation != null) {
      filter += ' && storage_location = "${widget.storageLocation!.id}"';
    } else {
      filter += ' && storage_location = ""';
    }

    final contRecords = await widget.pb.collection('containers').getFullList(filter: filter, sort: 'name');
    final containers = contRecords.map((r) => InventoryContainer.fromRecord(r)).toList();
    
    final allRoomContRecords = await widget.pb.collection('containers').getFullList(
      filter: 'room = "${widget.room.id}"',
      fields: 'storage_location',
    );
    final Map<String, int> locCounts = {};
    for (var r in allRoomContRecords) {
      final locId = r.getStringValue('storage_location');
      if (locId.isNotEmpty) locCounts[locId] = (locCounts[locId] ?? 0) + 1;
    }

    final itemRecords = await widget.pb.collection('items').getFullList(fields: 'container');
    final Map<String, int> counts = {};
    for (var record in itemRecords) {
      final containerId = record.getStringValue('container');
      if (containerId.isNotEmpty) counts[containerId] = (counts[containerId] ?? 0) + 1;
    }
    
    if (mounted) {
      setState(() {
        _containerItemCounts = counts;
        _locationContainerCounts = locCounts;
      });
    }
    return {'locations': locations, 'containers': containers};
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.storageLocation?.name ?? widget.room.name;
    final subtitle = widget.storageLocation != null ? 'In: ${widget.room.name}' : 'Übersicht';
    final imageUrl = widget.storageLocation != null && widget.storageLocation!.photo.isNotEmpty
        ? widget.pb.files.getUrl(widget.storageLocation!.record, widget.storageLocation!.photo).toString()
        : null;

    return InventoryPageLayout(
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        const SizedBox(width: 16),
      ],
      filterChips: [
        FilterChip(
          label: const Text('Alle anzeigen'),
          selected: !_onlyWithItems,
          onSelected: (val) => setState(() { _onlyWithItems = false; _refreshData(); }),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          showCheckmark: false,
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Nur belegte'),
          selected: _onlyWithItems,
          onSelected: (val) => setState(() { _onlyWithItems = true; _refreshData(); }),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          showCheckmark: false,
        ),
      ],
      floatingActionButton: _buildFab(context),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
          var locations = snapshot.data!['locations'] as List<StorageLocation>;
          var containers = snapshot.data!['containers'] as List<InventoryContainer>;

          if (_onlyWithItems) {
            containers = containers.where((c) => (_containerItemCounts[c.id] ?? 0) > 0).toList();
          }

          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (locations.isNotEmpty && !_onlyWithItems) ...[
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
    );
  }

  Widget _buildLocationsGrid(List<StorageLocation> locations) {
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 450, mainAxisExtent: 130, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: locations.length,
      itemBuilder: (context, index) => _buildLocationCard(locations[index]),
    );
  }

  Widget _buildLocationCard(StorageLocation loc) {
    String imageUrl = loc.photo.isNotEmpty ? widget.pb.files.getUrl(loc.record, loc.photo).toString() : '';
    final containerCount = _locationContainerCounts[loc.id] ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(32), boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 20, offset: const Offset(0, 4))]),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ContainerListScreen(pb: widget.pb, room: widget.room, storageLocation: loc))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(15), borderRadius: BorderRadius.circular(20)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageUrl.isNotEmpty ? Image.network(imageUrl, fit: BoxFit.cover) : Icon(loc.iconData, color: Theme.of(context).colorScheme.primary, size: 32),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withAlpha(isDark ? 50 : 100), borderRadius: BorderRadius.circular(20)),
                      child: Text('$containerCount Container', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (val) {
                  if (val == 'edit') _showAddLocationDialog(context, location: loc);
                  if (val == 'delete') _showDeleteLocationConfirmDialog(context, loc);
                },
                itemBuilder: (context) => [const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')), const PopupMenuItem(value: 'delete', child: Text('Löschen'))],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(32), boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => ItemListScreen(pb: widget.pb, container: container, room: widget.room, storageLocation: widget.storageLocation)));
            _refreshData();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(15), borderRadius: BorderRadius.circular(20)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: imageUrl.isNotEmpty ? Image.network(imageUrl, fit: BoxFit.cover) : Icon(container.iconData, color: Theme.of(context).colorScheme.primary, size: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(container.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('$itemCount Artikel', style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(200), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (val) async {
                    if (val == 'edit') _showAddContainerDialog(context, container: container);
                    if (val == 'delete') _showDeleteConfirmDialog(context, container);
                    if (val == 'move') {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => MoveContainerScreen(pb: widget.pb, container: container)));
                      if (result == true) _refreshData();
                    }
                  },
                  itemBuilder: (context) => [const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')), const PopupMenuItem(value: 'move', child: Text('Verschieben')), const PopupMenuItem(value: 'delete', child: Text('Löschen'))],
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
        if (widget.storageLocation == null) ...[
          StandardFab(heroTag: 'add_loc', label: 'Ablageort', onPressed: () => _showAddLocationDialog(context)),
          const SizedBox(width: 16),
        ],
        StandardFab(heroTag: 'add_cont', label: 'Container', onPressed: () => _showAddContainerDialog(context)),
      ],
    );
  }

  void _showAddLocationDialog(BuildContext context, {StorageLocation? location}) {
    showDialog(
      context: context,
      builder: (context) => InventoryForm(
        title: location == null ? 'Neuer Ablageort' : 'Ort bearbeiten',
        initialName: location?.name,
        initialPhotoUrl: location != null && location.photo.isNotEmpty ? widget.pb.files.getUrl(locRecord: location.record, fileName: location.photo).toString() : null,
        initialIcon: location?.iconName ?? 'shelves',
        showIcons: true,
        availableIcons: const ['shelves', 'door_sliding', 'home_repair_service'],
        pb: widget.pb,
        onSave: (name, quantity, imageFile, icon, labelId) async {
          final data = {'name': name, 'icon': icon};
          List<http.MultipartFile> files = [];
          if (imageFile != null) {
            if (kIsWeb) files.add(http.MultipartFile.fromBytes('photo', await imageFile.readAsBytes(), filename: imageFile.name));
            else files.add(await http.MultipartFile.fromPath('photo', imageFile.path));
          }
          try {
            if (location == null) { data['room'] = widget.room.id; await widget.pb.collection('storage_locations').create(body: data, files: files); }
            else await widget.pb.collection('storage_locations').update(location.id, body: data, files: files);
            if (context.mounted) Navigator.pop(context);
            _refreshData();
          } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
        },
      ),
    );
  }

  void _showAddContainerDialog(BuildContext context, {InventoryContainer? container}) {
    showDialog(
      context: context,
      builder: (context) => InventoryForm(
        title: container == null ? 'Neuer Container' : 'Bearbeiten',
        initialName: container?.name,
        initialPhotoUrl: container != null && container.photo.isNotEmpty ? widget.pb.files.getUrl(container.record, container.photo).toString() : null,
        initialIcon: container?.iconName ?? 'inventory_2',
        initialLabelId: container?.labelId,
        showIcons: true,
        showQrScanner: true,
        availableIcons: iconMapping.keys.toList(),
        pb: widget.pb,
        onSave: (name, quantity, imageFile, icon, labelId) async {
          final Map<String, dynamic> data = {'name': name, 'icon': icon, 'labelId': labelId.isEmpty ? null : labelId};
          if (widget.storageLocation != null) data['storage_location'] = widget.storageLocation!.id;
          List<http.MultipartFile> files = [];
          if (imageFile != null) {
            if (kIsWeb) files.add(http.MultipartFile.fromBytes('photo', await imageFile.readAsBytes(), filename: imageFile.name));
            else files.add(await http.MultipartFile.fromPath('photo', imageFile.path));
          }
          try {
            if (container == null) { data['room'] = widget.room.id; await widget.pb.collection('containers').create(body: data, files: files); }
            else await widget.pb.collection('containers').update(container.id, body: data, files: files);
            if (context.mounted) Navigator.pop(context);
            _refreshData();
          } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
        },
      ),
    );
  }

  void _showDeleteLocationConfirmDialog(BuildContext context, StorageLocation loc) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Ort löschen?'), content: Text('Soll "${loc.name}" wirklich gelöscht werden?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')), TextButton(onPressed: () async { final nav = Navigator.of(context); await widget.pb.collection('storage_locations').delete(loc.id); if (context.mounted) { nav.pop(); _refreshData(); } }, child: const Text('Löschen', style: TextStyle(color: Colors.red)))]));
  }

  void _showDeleteConfirmDialog(BuildContext context, InventoryContainer container) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Löschen?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')), TextButton(onPressed: () async { final nav = Navigator.of(context); await widget.pb.collection('containers').delete(container.id); if (context.mounted) { nav.pop(); _refreshData(); } }, child: const Text('Löschen', style: TextStyle(color: Colors.red)))]));
  }
}
