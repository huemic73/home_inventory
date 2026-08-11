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
  Map<String, int> _containerItemCounts = {};

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
    
    // Zähle Items pro Container
    final itemRecords = await widget.pb.collection('items').getFullList(fields: 'container');
    final Map<String, int> counts = {};
    for (var record in itemRecords) {
      final containerId = record.getStringValue('container');
      if (containerId.isNotEmpty) {
        counts[containerId] = (counts[containerId] ?? 0) + 1;
      }
    }
    
    setState(() {
      _containerItemCounts = counts;
    });

    return containers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(widget.room.name),
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: FutureBuilder<List<InventoryContainer>>(
              future: _containersFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                final containers = snapshot.data!;
                if (containers.isEmpty) {
                  return const SliverToBoxAdapter(child: Center(child: Text('Keine Container in diesem Raum.')));
                }

                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    mainAxisExtent: 80,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildContainerCard(context, containers[index]),
                    childCount: containers.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddContainerDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Neuer Container'),
      ),
    );
  }

  Widget _buildContainerCard(BuildContext context, InventoryContainer container) {
    final itemCount = _containerItemCounts[container.id] ?? 0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ItemListScreen(pb: widget.pb, container: container)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(container.iconData, color: Theme.of(context).colorScheme.secondary, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      container.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$itemCount Gegenstände',
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
    );
  }

  void _showAddContainerDialog(BuildContext context, {InventoryContainer? container}) {
    final controller = TextEditingController(text: container?.name);
    String selectedIcon = container?.iconName ?? 'inventory_2';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(container == null ? 'Neuer Container' : 'Container bearbeiten'),
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
                        color: selectedIcon == e.key ? Theme.of(context).colorScheme.secondaryContainer : null,
                        border: Border.all(color: selectedIcon == e.key ? Theme.of(context).colorScheme.secondary : Colors.grey.shade300),
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
                  if (container == null) {
                    data['room'] = widget.room.id;
                    await widget.pb.collection('containers').create(body: data);
                  } else {
                    await widget.pb.collection('containers').update(container.id, body: data);
                  }
                  if (mounted) Navigator.pop(context);
                  _refreshContainers();
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(onPressed: () async {
            await widget.pb.collection('containers').delete(container.id);
            if (mounted) Navigator.pop(context);
            _refreshContainers();
          }, child: const Text('Löschen', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
