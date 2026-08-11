import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'container_list_screen.dart';
import 'item_list_screen.dart'; // Import hinzugefügt

class RoomListScreen extends StatefulWidget {
  final PocketBase pb;

  const RoomListScreen({super.key, required this.pb});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  late Future<List<Room>> _roomsFuture;

  @override
  void initState() {
    super.initState();
    _refreshRooms();
  }

  void _refreshRooms() {
    setState(() {
      _roomsFuture = _fetchRooms();
    });
  }

  Future<List<Room>> _fetchRooms() async {
    final records = await widget.pb.collection('rooms').getFullList(
      sort: 'name',
    );
    return records.map((r) => Room.fromRecord(r)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventar'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Alle Gegenstände suchen',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ItemListScreen(pb: widget.pb), // container: null zeigt alle
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRooms,
          ),
        ],
      ),
      body: FutureBuilder<List<Room>>(
        future: _roomsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final rooms = snapshot.data ?? [];

          return ListView(
            children: [
              // Spezial-Eintrag für unzugeordnete Gegenstände
              ListTile(
                leading: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.secondary),
                title: const Text('Ohne Zuordnung'),
                subtitle: const Text('Gegenstände ohne Box oder Raum'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemListScreen(
                        pb: widget.pb,
                        onlyUnassigned: true,
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              if (rooms.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: Text('Noch keine Räume angelegt.')),
                ),
              ...rooms.map((room) => ListTile(
                leading: const Icon(Icons.meeting_room),
                title: Text(room.name),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAddRoomDialog(context, room: room);
                    } else if (value == 'delete') {
                      _showDeleteConfirmDialog(context, room);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                    const PopupMenuItem(value: 'delete', child: Text('Löschen')),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContainerListScreen(
                        pb: widget.pb,
                        room: room,
                      ),
                    ),
                  );
                },
              )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddRoomDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddRoomDialog(BuildContext context, {Room? room}) {
    final controller = TextEditingController(text: room?.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(room == null ? 'Neuer Raum' : 'Raum bearbeiten'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                if (room == null) {
                  await widget.pb.collection('rooms').create(body: {'name': controller.text});
                } else {
                  await widget.pb.collection('rooms').update(room.id, body: {'name': controller.text});
                }
                if (mounted) Navigator.pop(context);
                _refreshRooms();
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Room room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raum löschen?'),
        content: Text('Möchtest du "${room.name}" wirklich löschen? Alle darin enthaltenen Container und Items bleiben in der Datenbank, verlieren aber ihre Zuordnung.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await widget.pb.collection('rooms').delete(room.id);
              if (mounted) Navigator.pop(context);
              _refreshRooms();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}
