import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'item_list_screen.dart';
import 'move_container_screen.dart';
import 'pick_unassigned_items_screen.dart';
import 'scanner_screen.dart';
import 'bulk_qr_print_screen.dart';
import 'user_profile_screen.dart';
import 'global_search_screen.dart';
import 'ui_components.dart';

class RoomListScreen extends StatefulWidget {
  final PocketBase pb;
  const RoomListScreen({super.key, required this.pb});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  late Future<List<StorageNode>> _nodesFuture;
  Map<String, int> _childNodeCounts = {};
  Map<String, int> _totalItemCounts = {}; // Neu: Summe aller Artikel (inkl. Unter-Nodes)
  Set<String> _occupiedNodeIds = {}; 
  int _unassignedItemCount = 0;
  bool _onlyOccupied = false;

  @override
  void initState() {
    super.initState();
    _refreshNodes();
  }

  void _refreshNodes() {
    _nodesFuture = _fetchNodes();
    setState(() {});
  }

  Future<List<StorageNode>> _fetchNodes() async {
    // 1. Alles laden für Berechnungen
    final allNodesRecords = await widget.pb.collection('nodes').getFullList();
    final allItemsRecords = await widget.pb.collection('items').getFullList();
    
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

    // 2. Rekursive Berechnung von Artikeln und "Belegt"-Status
    final Map<String, int> totalCounts = {};
    final Set<String> occupied = {};

    int calculateRecursive(String nodeId) {
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

    // Für alle Root-Nodes anstoßen
    for (var node in allNodesRecords.where((r) => r.getStringValue('parent').isEmpty)) {
      calculateRecursive(node.id);
    }

    // 3. Root-Nodes für Anzeige holen
    final records = await widget.pb.collection('nodes').getFullList(
      filter: 'parent = ""',
      sort: 'name',
    );
    final nodes = records.map((r) => StorageNode.fromRecord(r)).toList();
    
    final Map<String, int> childCounts = {};
    for (var r in allNodesRecords) {
      final pId = r.getStringValue('parent');
      if (pId.isNotEmpty) childCounts[pId] = (childCounts[pId] ?? 0) + 1;
    }

    final unassignedItems = await widget.pb.collection('items').getFullList(filter: 'node = ""', fields: 'id');
    
    if (mounted) {
      setState(() {
        _childNodeCounts = childCounts;
        _totalItemCounts = totalCounts;
        _occupiedNodeIds = occupied;
        _unassignedItemCount = unassignedItems.length;
      });
    }
    return nodes;
  }

  @override
  Widget build(BuildContext context) {
    return InventoryPageLayout(
      title: 'Meine Bereiche',
      subtitle: 'Übersicht',
      drawer: _buildDrawer(context),
      actions: [
        IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ScannerScreen(pb: widget.pb)))),
        IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GlobalSearchScreen(pb: widget.pb)))),
        const SizedBox(width: 16),
      ],
      filterChips: [
        FilterChip(
          label: const Text('Alles'), 
          selected: !_onlyOccupied, 
          onSelected: (val) => setState(() => _onlyOccupied = false), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
          showCheckmark: false
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Nur belegte'), 
          selected: _onlyOccupied, 
          onSelected: (val) => setState(() => _onlyOccupied = true), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
          showCheckmark: false
        ),
      ],
      sectionTitle: 'Deine Bereiche',
      floatingActionButton: InventoryActionFab(
        actions: [
          InventoryAction(
            label: 'Bereich hinzufügen',
            icon: Icons.domain_add,
            isPrimary: true,
            onTap: () => _showAddNodeDialog(context),
          ),
          InventoryAction(
            label: 'Gegenstand hinzufügen',
            icon: Icons.label_outlined,
            onTap: () => _showAddItemDialog(context),
          ),
        ],
      ),
      slivers: [
        FutureBuilder<List<StorageNode>>(
          future: _nodesFuture,
          builder: (context, snapshot) {
            // ... (Error-Handling bleibt gleich)
            if (snapshot.hasError) {
              return SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Fehler beim Laden: ${snapshot.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(onPressed: _refreshNodes, child: const Text('Erneut versuchen')),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
            
            var nodes = snapshot.data!;
            if (_onlyOccupied) {
              nodes = nodes.where((n) => _occupiedNodeIds.contains(n.id)).toList();
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSpecialTile(context),
                  const SizedBox(height: 24),
                  if (nodes.isEmpty)
                    const Center(child: Text('Noch keine Bereiche gefunden.'))
                  else
                    GridView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 400, mainAxisExtent: 180, mainAxisSpacing: 20, crossAxisSpacing: 20),
                      itemCount: nodes.length,
                      itemBuilder: (context, index) {
                        final node = nodes[index];
                        return InventoryCard(
                          entity: node,
                          pb: widget.pb,
                          onRefresh: _refreshNodes,
                          subtitleOverride: '${_totalItemCounts[node.id] ?? 0} Gegenstände · ${_childNodeCounts[node.id] ?? 0} Unterelemente',
                          popupMenu: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz), 
                            onSelected: (val) async { 
                              if (val == 'edit') {
                                _showAddNodeDialog(context, node: node);
                              } else if (val == 'move') {
                                final result = await Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (context) => MoveContainerScreen(pb: widget.pb, node: node))
                                );
                                if (result == true) _refreshNodes();
                              } else if (val == 'pick') {
                                final result = await Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (context) => PickUnassignedItemsScreen(pb: widget.pb, targetNode: node))
                                );
                                if (result == true) _refreshNodes();
                              } else if (val == 'delete') {
                                _showDeleteConfirmDialog(context, node); 
                              }
                            }, 
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')), 
                              const PopupMenuItem(value: 'pick', child: Text('Gegenstand einsortieren')), 
                              const PopupMenuItem(value: 'move', child: Text('Verschieben')),
                              const PopupMenuItem(value: 'delete', child: Text('Löschen'))
                            ],
                          ),
                        );
                      },
                    ),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NavigationDrawer(
      backgroundColor: Theme.of(context).drawerTheme.backgroundColor,
      surfaceTintColor: Colors.transparent,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [Text('Meine Bereiche', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), Text('Inventar-Übersicht', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))]),
        ),
        const SizedBox(height: 12),
        NavigationDrawerDestination(icon: Icon(Icons.dashboard_outlined, color: isDark ? Colors.white70 : null), label: Text('Übersicht', style: TextStyle(color: isDark ? Colors.white : null))),
        NavigationDrawerDestination(icon: Icon(Icons.print_outlined, color: isDark ? Colors.white70 : null), label: Text('Etiketten', style: TextStyle(color: isDark ? Colors.white : null))),
        NavigationDrawerDestination(icon: Icon(Icons.person_outline, color: isDark ? Colors.white70 : null), label: Text('Profil & Sicherheit', style: TextStyle(color: isDark ? Colors.white : null))),
        const Divider(indent: 16, endIndent: 16),
        AboutListTile(icon: Icon(Icons.info_outline, color: isDark ? Colors.white70 : null), applicationName: 'Heiminventarisierung', child: Text('Über die App', style: TextStyle(color: isDark ? Colors.white : null))),
      ],
      onDestinationSelected: (index) {
        Navigator.pop(context);
        if (index == 1) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => BulkQrPrintScreen(pb: widget.pb)));
        } else if (index == 2) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(pb: widget.pb)));
        }
      },
    );
  }

  Widget _buildSpecialTile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(color: _unassignedItemCount > 0 ? Theme.of(context).colorScheme.primary : (isDark ? Colors.white10 : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(150)), borderRadius: BorderRadius.circular(32), boxShadow: [if (_unassignedItemCount > 0) BoxShadow(color: Theme.of(context).colorScheme.primary.withAlpha(60), blurRadius: 20, offset: const Offset(0, 10))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        title: Text('Ohne Zuordnung', style: TextStyle(color: _unassignedItemCount > 0 || isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(_unassignedItemCount > 0 ? '$_unassignedItemCount Gegenstände warten auf einen Platz' : 'Alles perfekt einsortiert!', style: TextStyle(color: _unassignedItemCount > 0 || isDark ? Colors.white70 : Colors.black54)),
        trailing: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _unassignedItemCount > 0 || isDark ? Colors.white24 : Colors.black12, shape: BoxShape.circle), child: Icon(_unassignedItemCount > 0 ? Icons.arrow_forward : Icons.check, color: _unassignedItemCount > 0 || isDark ? Colors.white : Colors.black54)),
        onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => ItemListScreen(pb: widget.pb, onlyUnassigned: true))); _refreshNodes(); },
      ),
    );
  }

  void _showAddNodeDialog(BuildContext context, {StorageNode? node}) {
    showDialog(
      context: context,
      builder: (context) => InventoryForm(
        title: node == null ? 'Neuer Bereich' : 'Bereich bearbeiten',
        initialName: node?.name,
        initialIcon: node?.iconName ?? 'area',
        initialType: node?.type ?? NodeType.bereich,
        showIcons: true,
        showTypeSelector: true, // Erlaube Wahl zwischen AREA und ROOM
        pb: widget.pb,
        onSave: (String n, String d, int q, XFile? f, String i, String l, NodeType t, List<String> ts, bool deleteImage) async {
          final Map<String, dynamic> data = {
            'name': n, 
            'icon': i, 
            'type': t.toString().split('.').last,
            'parent': '',
          };
          if (node != null) data['type'] = node.type.toString().split('.').last;
          
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
            _refreshNodes();
          } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, StorageNode node) {
    // ... (bestehender Code)
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
          final Map<String, dynamic> body = {
            'name': n, 
            'description': d,
            'quantity': q,
            'tags': ts,
            'node': '', // Ohne Zuordnung
          };
          List<http.MultipartFile> files = [];
          if (f != null) {
            final bytes = await f.readAsBytes();
            files.add(http.MultipartFile.fromBytes('photo', bytes, filename: f.name));
          }
          try {
            await widget.pb.collection('items').create(body: body, files: files);
            if (context.mounted) Navigator.pop(context);
            _refreshNodes();
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
          }
        },
      ),
    );
  }
}
