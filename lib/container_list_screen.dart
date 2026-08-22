import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'move_container_screen.dart';
import 'pick_unassigned_items_screen.dart';
import 'scanner_screen.dart';
import 'global_search_screen.dart';
import 'ui_components.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContainerListScreen extends StatefulWidget {
  final PocketBase pb;
  final StorageNode parentNode;

  const ContainerListScreen({super.key, required this.pb, required this.parentNode});

  @override
  State<ContainerListScreen> createState() => _ContainerListScreenState();
}

class _ContainerListScreenState extends State<ContainerListScreen> {
  late Future<Map<String, dynamic>> _dataFuture;
  late StorageNode _currentNode;
  Map<String, int> _childNodeCounts = {};
  Map<String, int> _totalItemCounts = {}; // Summe aller Artikel inkl. Unter-Nodes
  Set<String> _occupiedNodeIds = {};
  List<StorageNode> _path = []; // Neu: Pfad-Tracking
  bool _onlyOccupied = false;

  @override
  void initState() {
    super.initState();
    _currentNode = widget.parentNode;
    _refreshData();
  }

  void _refreshData() {
    _dataFuture = _fetchData();
    setState(() {});
  }

  Future<Map<String, dynamic>> _fetchData() async {
    // Current node aktualisieren
    try {
      final parentRecord = await widget.pb.collection('nodes').getOne(_currentNode.id, expand: 'tags');
      _currentNode = StorageNode.fromRecord(parentRecord);
    } catch (e) {
      debugPrint('Fehler beim Aktualisieren der aktuellen Node: $e');
    }

    // 1. Alle relevanten Daten laden
    final allNodesRecords = await widget.pb.collection('nodes').getFullList(expand: 'tags');
    final allItemsRecords = await widget.pb.collection('items').getFullList(expand: 'node.parent.parent.parent.parent.parent,tags');

    // Pfad berechnen
    final Map<String, StorageNode> allNodesMap = {
      for (var r in allNodesRecords) r.id: StorageNode.fromRecord(r)
    };
    
    List<StorageNode> currentPath = [];
    StorageNode? current = allNodesMap[_currentNode.id];
    while (current != null) {
      currentPath.add(current);
      current = current.parentId != null ? allNodesMap[current.parentId] : null;
    }
    
    if (mounted) {
      setState(() {
        _path = currentPath.reversed.toList();
      });
    }

    final Map<String, List<String>> parentToChildren = {};
    for (var r in allNodesRecords) {
      final pId = r.getStringValue('parent');
      if (pId.isNotEmpty) parentToChildren.putIfAbsent(pId, () => []).add(r.id);
    }

    final Map<String, int> nodeDirectItems = {};
    for (var r in allItemsRecords) {
      final nId = r.getStringValue('node');
      if (nId.isNotEmpty) {
        nodeDirectItems[nId] = (nodeDirectItems[nId] ?? 0) + r.getIntValue('quantity');
      }
    }

    // 2. Rekursive Berechnung
    final Map<String, int> totalCounts = {};
    final Set<String> occupied = {};

    int calculateRecursive(String nodeId) {
      // Memoization: Wenn wir dieses Node schon berechnet haben, überspringen
      if (totalCounts.containsKey(nodeId)) return totalCounts[nodeId]!;

      int count = nodeDirectItems[nodeId] ?? 0;
      final children = parentToChildren[nodeId] ?? [];
      for (var childId in children) {
        count += calculateRecursive(childId);
      }
      totalCounts[nodeId] = count;
      if (count > 0) occupied.add(nodeId);
      return count;
    }

    // Berechnung für alle Nodes starten
    for (var node in allNodesRecords) {
      calculateRecursive(node.id);
    }

    // 3. Daten für die aktuelle Node filtern
    final currentNodes = allNodesRecords
        .where((r) => r.getStringValue('parent') == _currentNode.id)
        .map((r) => StorageNode.fromRecord(r))
        .toList();

    final currentItems = allItemsRecords
        .where((r) => r.getStringValue('node') == _currentNode.id)
        .map((r) => Item.fromRecord(r))
        .toList();

    final Map<String, int> childCounts = {};
    for (var r in allNodesRecords) {
      final pId = r.getStringValue('parent');
      if (pId.isNotEmpty) childCounts[pId] = (childCounts[pId] ?? 0) + 1;
    }

    if (mounted) {
      setState(() {
        _childNodeCounts = childCounts;
        _totalItemCounts = totalCounts;
        _occupiedNodeIds = occupied;
      });
    }
    
    final prefs = await SharedPreferences.getInstance();
    final orderedIds = prefs.getStringList('sort_order_container_${_currentNode.id}');
    final sortedNodes = sortNodes(currentNodes, orderedIds);

    return {
      'locations': sortedNodes.where((n) => n.type != NodeType.container).toList(),
      'containers': sortedNodes.where((n) => n.type == NodeType.container).toList(),
      'items': currentItems,
    };
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _currentNode.photo.isNotEmpty
        ? widget.pb.files.getUrl(_currentNode.record, _currentNode.photo).toString()
        : null;

    return InventoryPageLayout(
      title: _currentNode.name,
      subtitle: '${_currentNode.type.label} · Inhaltsverzeichnis',
      imageUrl: imageUrl,
      breadcrumbs: _path,
      onHomePressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
      actions: [
        IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ScannerScreen(pb: widget.pb)))),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _showAddNodeDialog(context, node: _currentNode),
        ),
        IconButton(
          icon: const Icon(Icons.sort),
          onPressed: () async {
            final data = await _dataFuture;
            final List<StorageNode> locations = List<StorageNode>.from(data['locations'] ?? []);
            final List<StorageNode> containers = List<StorageNode>.from(data['containers'] ?? []);
            final allSubNodes = [...locations, ...containers];
            
            if (!mounted) return;
            if (allSubNodes.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Keine Elemente zum Sortieren vorhanden.')),
              );
              return;
            }

            final sorted = await showDialog<bool>(
              context: context,
              builder: (context) => ReorderNodesDialog(
                nodes: allSubNodes,
                sortKey: 'sort_order_container_${_currentNode.id}',
              ),
            );
            if (sorted == true) {
              _refreshData();
            }
          },
        ),
        IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GlobalSearchScreen(pb: widget.pb)))),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
      ],
      filterChips: [
        FilterChip(
          label: const Text('Alles'),
          selected: !_onlyOccupied,
          onSelected: (val) => setState(() { _onlyOccupied = false; }),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          showCheckmark: false,
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Nur belegte'),
          selected: _onlyOccupied,
          onSelected: (val) => setState(() { _onlyOccupied = true; }),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          showCheckmark: false,
        ),
      ],
      floatingActionButton: InventoryActionFab(
        actions: [
          InventoryAction(
            label: 'Gegenstand hinzufügen',
            icon: Icons.label_outlined,
            isPrimary: true,
            onTap: () => _showAddItemDialog(context),
          ),
          InventoryAction(
            label: '${_currentNode.type.defaultChildType.label} hinzufügen',
            icon: Icons.add_box_outlined,
            onTap: () => _showAddNodeDialog(context),
          ),
          InventoryAction(
            label: 'Gegenstand hier einsortieren',
            icon: Icons.move_to_inbox_outlined,
            onTap: () async {
              final res = await Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => PickUnassignedItemsScreen(pb: widget.pb, targetNode: _currentNode))
              );
              if (res == true) _refreshData();
            },
          ),
        ],
      ),
      slivers: [
        SliverToBoxAdapter(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              var locations = snapshot.data!['locations'] as List<StorageNode>;
              var containers = snapshot.data!['containers'] as List<StorageNode>;
              var items = snapshot.data!['items'] as List<Item>;

              if (_onlyOccupied) {
                locations = locations.where((n) => _occupiedNodeIds.contains(n.id)).toList();
                containers = containers.where((n) => _occupiedNodeIds.contains(n.id)).toList();
              }

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentNode.description.isNotEmpty) ...[
                      Text(
                        _currentNode.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary.withAlpha(200),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_currentNode.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _currentNode.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: tag.colorData.withAlpha(20),
                              border: Border.all(color: tag.colorData.withAlpha(50)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag.name,
                              style: TextStyle(
                                color: tag.colorData,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                    if (locations.isNotEmpty) ...[
                      const Text('Unterteilungen (Räume/Orte)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      _buildNodesGrid(locations),
                      const SizedBox(height: 32),
                    ],
                    if (containers.isNotEmpty) ...[
                      const Text('Container / Boxen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      _buildNodesGrid(containers),
                      const SizedBox(height: 32),
                    ],
                    if (items.isNotEmpty) ...[
                      const Text('Gegenstände an diesem Ort', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      _buildItemsList(items),
                    ],
                    if (locations.isEmpty && containers.isEmpty && items.isEmpty) 
                      const Center(child: Text('Hier ist noch alles leer.')),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNodesGrid(List<StorageNode> nodes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 450,
        mainAxisExtent: 180, // Angepasst an InventoryCard Höhe
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return InventoryCard(
          entity: node,
          pb: widget.pb,
          onRefresh: _refreshData,
          subtitleOverride: formatSubtitle(
            _totalItemCounts[node.id] ?? 0,
            _childNodeCounts[node.id] ?? 0,
          ),
          popupMenu: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (val) async {
              if (val == 'edit') {
                _showAddNodeDialog(context, node: node);
              } else if (val == 'move') {
                final result = await Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => MoveContainerScreen(pb: widget.pb, node: node))
                );
                if (result == true) _refreshData();
              } else if (val == 'pick') {
                final result = await Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => PickUnassignedItemsScreen(pb: widget.pb, targetNode: node))
                );
                if (result == true) _refreshData();
              } else if (val == 'delete') {
                _showDeleteConfirmDialog(context, node);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
              const PopupMenuItem(value: 'pick', child: Text('Gegenstand einsortieren')),
              const PopupMenuItem(value: 'move', child: Text('Verschieben')),
              const PopupMenuItem(value: 'delete', child: Text('Löschen')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsList(List<Item> items) {
    return Column(
      children: items.map((item) => InventoryListTile(
        entity: item,
        pb: widget.pb,
        onRefresh: _refreshData,
      )).toList(),
    );
  }

  void _showAddNodeDialog(BuildContext context, {StorageNode? node}) {
    showDialog(
      context: context,
      builder: (context) => InventoryForm(
        title: node == null ? 'Neues Element' : 'Bearbeiten',
        initialName: node?.name,
        initialIcon: node?.iconName,
        initialType: node?.type ?? NodeType.container,
        initialDescription: node?.description,
        initialTagIds: node?.tagIds,
        showIcons: true,
        showTypeSelector: true,
        showDescription: true,
        showTagSelector: true,
        pb: widget.pb,
        onSave: (String n, String d, int q, XFile? f, String i, String l, NodeType t, List<String> ts, bool deleteImage) async {
          final Map<String, dynamic> data = {
            'name': n,
            'icon': i,
            'parent': widget.parentNode.id,
            'type': t.toString().split('.').last,
            'description': d,
            'tags': ts,
          };
          
          if (deleteImage) {
            data['photo'] = null;
          }

          List<http.MultipartFile> files = [];
          if (f != null) {
            final bytes = await f.readAsBytes();
            files.add(http.MultipartFile.fromBytes('photo', bytes, filename: f.name));
          }

          try {
            if (node == null) {
              await widget.pb.collection('nodes').create(body: data, files: files);
            } else {
              await widget.pb.collection('nodes').update(node.id, body: data, files: files);
            }
            if (context.mounted) Navigator.pop(context);
            _refreshData();
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
          }
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, StorageNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Löschen?'),
        content: const Text('Dies löscht nur diesen Knoten. Unterelemente müssen separat verschoben werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await widget.pb.collection('nodes').delete(node.id);
              if (mounted) { 
                nav.pop(); 
                _refreshData(); 
              }
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => InventoryForm(
        title: 'Gegenstand hinzufügen',
        showQuantity: true,
        showTagSelector: true,
        pb: widget.pb,
        onSave: (String n, String d, int q, XFile? f, String i, String l, NodeType t, List<String> ts, bool di) async {
          final data = {
            'name': n,
            'description': d,
            'quantity': q,
            'node': widget.parentNode.id,
            'tags': ts,
          };
          
          List<http.MultipartFile> files = [];
          if (f != null) {
            final bytes = await f.readAsBytes();
            files.add(http.MultipartFile.fromBytes('photo', bytes, filename: f.name));
          }

          try {
            await widget.pb.collection('items').create(body: data, files: files);
            if (context.mounted) Navigator.pop(context);
            _refreshData();
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
          }
        },
      ),
    );
  }
}
