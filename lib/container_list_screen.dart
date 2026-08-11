import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'item_list_screen.dart';

class ContainerListScreen extends StatefulWidget {
  final PocketBase pb;
  final Room room;

  const ContainerListScreen({super.key, required this.pb, required this.room});

  @override
  State<ContainerListScreen> createState() => _ContainerListScreenState();
}

class _ContainerListScreenState extends State<ContainerListScreen> {
  late Future<List<InventoryContainer>> _containersFuture;

  @override
  void initState() {
    super.initState();
    _refreshContainers();
  }

  void _refreshContainers() {
    setState(() {
      _containersFuture = _fetchContainers();
    });
  }

  Future<List<InventoryContainer>> _fetchContainers() async {
    final records = await widget.pb.collection('containers').getFullList(
      filter: 'room = "${widget.room.id}"',
      sort: 'name',
    );
    return records.map((r) => InventoryContainer.fromRecord(r)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Container in ${widget.room.name}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshContainers,
          ),
        ],
      ),
      body: FutureBuilder<List<InventoryContainer>>(
        future: _containersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final containers = snapshot.data ?? [];
          if (containers.isEmpty) {
            return const Center(child: Text('Keine Container in diesem Raum.'));
          }

          return ListView.builder(
            itemCount: containers.length,
            itemBuilder: (context, index) {
              final container = containers[index];
              return ListTile(
                leading: const Icon(Icons.inventory),
                title: Text(container.name),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAddContainerDialog(context, container: container);
                    } else if (value == 'delete') {
                      _showDeleteConfirmDialog(context, container);
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
                      builder: (context) => ItemListScreen(
                        pb: widget.pb,
                        container: container,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddContainerDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddContainerDialog(BuildContext context, {InventoryContainer? container}) {
    final controller = TextEditingController(text: container?.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(container == null ? 'Neuer Container' : 'Container bearbeiten'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name (z.B. Box 1, Regal A)'),
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
                if (container == null) {
                  await widget.pb.collection('containers').create(body: {
                    'name': controller.text,
                    'room': widget.room.id,
                  });
                } else {
                  await widget.pb.collection('containers').update(container.id, body: {
                    'name': controller.text,
                  });
                }
                if (mounted) Navigator.pop(context);
                _refreshContainers();
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, InventoryContainer container) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Container löschen?'),
        content: Text('Möchtest du "${container.name}" wirklich löschen? Die enthaltenen Items bleiben erhalten, verlieren aber ihre Zuordnung zu diesem Container.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await widget.pb.collection('containers').delete(container.id);
              if (mounted) Navigator.pop(context);
              _refreshContainers();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}
