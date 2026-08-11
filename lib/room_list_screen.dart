import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'container_list_screen.dart';
import 'item_list_screen.dart';

class RoomListScreen extends StatefulWidget {
  final PocketBase pb;

  const RoomListScreen({super.key, required this.pb});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  late Future<List<Room>> _roomsFuture;
  Map<String, int> _roomContainerCounts = {};

  @override
  void initState() {
    super.initState();
    _refreshRooms();
  }

  void _refreshRooms() {
    _roomsFuture = _fetchRooms();
    setState(() {});
  }

  Future<List<Room>> _fetchRooms() async {
    final records = await widget.pb.collection('rooms').getFullList(sort: 'name');
    final rooms = records.map((r) => Room.fromRecord(r)).toList();
    
    // Zähle Container pro Raum
    final containerRecords = await widget.pb.collection('containers').getFullList(fields: 'room');
    final Map<String, int> counts = {};
    for (var record in containerRecords) {
      final roomId = record.getStringValue('room');
      counts[roomId] = (counts[roomId] ?? 0) + 1;
    }
    
    setState(() {
      _roomContainerCounts = counts;
    });

    return rooms;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Mein Inventar'),
            actions: [
              IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemListScreen(pb: widget.pb)))),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshRooms),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: _buildSpecialTile(
                context,
                title: 'Ohne Zuordnung',
                icon: Icons.help_center_outlined,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemListScreen(pb: widget.pb, onlyUnassigned: true))),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: FutureBuilder<List<Room>>(
              future: _roomsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                final rooms = snapshot.data!;
                
                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    mainAxisExtent: 80,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildRoomCard(context, rooms[index]),
                    childCount: rooms.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRoomDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Neuer Raum'),
      ),
    );
  }

  Widget _buildSpecialTile(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, Room room) {
    final containerCount = _roomContainerCounts[room.id] ?? 0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ContainerListScreen(pb: widget.pb, room: room))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(room.iconData, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$containerCount Container',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (val) {
                  if (val == 'edit') _showAddRoomDialog(context, room: room);
                  if (val == 'delete') _showDeleteConfirmDialog(context, room);
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

  void _showAddRoomDialog(BuildContext context, {Room? room}) {
    final controller = TextEditingController(text: room?.name);
    String selectedIcon = room?.iconName ?? 'meeting_room';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(room == null ? 'Neuer Raum' : 'Raum bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                const Text('Icon wählen:'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: iconMapping.entries.map((e) => GestureDetector(
                    onTap: () => setState(() => selectedIcon = e.key),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selectedIcon == e.key ? Theme.of(context).colorScheme.primaryContainer : null,
                        border: Border.all(color: selectedIcon == e.key ? Theme.of(context).colorScheme.primary : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(e.value, size: 24),
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
                  final data = {'name': controller.text, 'icon': selectedIcon};
                  if (room == null) {
                    await widget.pb.collection('rooms').create(body: data);
                  } else {
                    await widget.pb.collection('rooms').update(room.id, body: data);
                  }
                  if (mounted) Navigator.pop(context);
                  _refreshRooms();
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Room room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Löschen?'),
        content: Text('Soll "${room.name}" wirklich gelöscht werden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(onPressed: () async {
            await widget.pb.collection('rooms').delete(room.id);
            if (mounted) Navigator.pop(context);
            _refreshRooms();
          }, child: const Text('Löschen', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
