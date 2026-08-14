import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'container_list_screen.dart';
import 'item_list_screen.dart';
import 'scanner_screen.dart';
import 'bulk_qr_print_screen.dart';
import 'user_profile_screen.dart';
import 'global_search_screen.dart';
import 'inventory_form.dart'; 

class RoomListScreen extends StatefulWidget {
  final PocketBase pb;

  const RoomListScreen({super.key, required this.pb});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  late Future<List<Room>> _roomsFuture;
  Map<String, int> _roomContainerCounts = {};
  Map<String, int> _roomLocationCounts = {}; // Neu: Zähler für Orte
  int _unassignedItemCount = 0; // Neu: Zähler für lose Artikel
  bool _onlyWithContainers = false;

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
    
    final containerRecords = await widget.pb.collection('containers').getFullList(fields: 'room');
    final Map<String, int> counts = {};
    for (var record in containerRecords) {
      final roomId = record.getStringValue('room');
      counts[roomId] = (counts[roomId] ?? 0) + 1;
    }

    final locationRecords = await widget.pb.collection('storage_locations').getFullList(fields: 'room');
    final Map<String, int> locCounts = {};
    for (var record in locationRecords) {
      final roomId = record.getStringValue('room');
      locCounts[roomId] = (locCounts[roomId] ?? 0) + 1;
    }
    
    // Zähle lose Artikel (ohne Container)
    final unassignedItems = await widget.pb.collection('items').getFullList(
      filter: 'container = ""',
      fields: 'id',
    );
    
    if (mounted) {
      setState(() {
        _roomContainerCounts = counts;
        _roomLocationCounts = locCounts;
        _unassignedItemCount = unassignedItems.length;
      });
    }

    return rooms;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      drawer: _buildDrawer(context),
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
              expandedHeight: 120,
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                title: Text(
                  'Heiminventarisierung',
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Icon(Icons.qr_code_scanner, color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ScannerScreen(pb: widget.pb))),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Icon(Icons.search, color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                  onPressed: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => GlobalSearchScreen(pb: widget.pb))
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: _buildSpecialTile(context),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Alle Räume'),
                      selected: !_onlyWithContainers,
                      onSelected: (val) => setState(() => _onlyWithContainers = false),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      showCheckmark: false,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Nur mit Containern'),
                      selected: _onlyWithContainers,
                      onSelected: (val) => setState(() => _onlyWithContainers = true),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      showCheckmark: false,
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: FutureBuilder<List<Room>>(
                future: _roomsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                  }
                  var rooms = snapshot.data ?? [];
                  
                  // Filter anwenden
                  if (_onlyWithContainers) {
                    rooms = rooms.where((r) => (_roomContainerCounts[r.id] ?? 0) > 0).toList();
                  }

                  if (rooms.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(_onlyWithContainers ? 'Keine Räume mit Containern gefunden.' : 'Starte dein Inventar!'),
                        ),
                      ),
                    );
                  }

                  return SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      mainAxisExtent: 180, // Größere Kacheln für schöneres Design
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildRoomCard(context, rooms[index]),
                      childCount: rooms.length,
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
        onPressed: () => _showAddRoomDialog(context),
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NavigationDrawer(
      backgroundColor: Theme.of(context).drawerTheme.backgroundColor,
      surfaceTintColor: Colors.transparent,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Heiminventar', 
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold, 
                  color: isDark ? Colors.white : Colors.black87
                )
              ),
              Text(
                'Modern & Strukturiert',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        NavigationDrawerDestination(
          icon: Icon(Icons.dashboard_outlined, color: isDark ? Colors.white70 : null),
          selectedIcon: const Icon(Icons.dashboard),
          label: Text('Übersicht', style: TextStyle(color: isDark ? Colors.white : null)),
        ),
        NavigationDrawerDestination(
          icon: Icon(Icons.print_outlined, color: isDark ? Colors.white70 : null),
          label: Text('Etiketten', style: TextStyle(color: isDark ? Colors.white : null)),
        ),
        NavigationDrawerDestination(
          icon: Icon(Icons.person_outline, color: isDark ? Colors.white70 : null),
          label: Text('Profil & Sicherheit', style: TextStyle(color: isDark ? Colors.white : null)),
        ),
        const Divider(indent: 16, endIndent: 16),
        AboutListTile(
          icon: Icon(Icons.info_outline, color: isDark ? Colors.white70 : null), 
          applicationName: 'Heiminventarisierung',
          child: Text('Über die App', style: TextStyle(color: isDark ? Colors.white : null)),
        ),
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
      decoration: BoxDecoration(
        color: _unassignedItemCount > 0 
            ? Theme.of(context).colorScheme.primary 
            : (isDark ? Colors.white10 : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(150)),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          if (_unassignedItemCount > 0)
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withAlpha(60),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        title: Text(
          'Ohne Zuordnung', 
          style: TextStyle(
            color: _unassignedItemCount > 0 || isDark ? Colors.white : Colors.black87, 
            fontWeight: FontWeight.bold, 
            fontSize: 18
          )
        ),
        subtitle: Text(
          _unassignedItemCount > 0 
              ? '$_unassignedItemCount Artikel warten auf einen Platz' 
              : 'Alles perfekt einsortiert!',
          style: TextStyle(
            color: _unassignedItemCount > 0 || isDark ? Colors.white70 : Colors.black54,
          )
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _unassignedItemCount > 0 || isDark ? Colors.white24 : Colors.black12, 
            shape: BoxShape.circle
          ),
          child: Icon(
            _unassignedItemCount > 0 ? Icons.arrow_forward : Icons.check, 
            color: _unassignedItemCount > 0 || isDark ? Colors.white : Colors.black54
          ),
        ),
        onTap: () async {
          await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => ItemListScreen(pb: widget.pb, onlyUnassigned: true))
          );
          _refreshRooms();
        },
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, Room room) {
    final containerCount = _roomContainerCounts[room.id] ?? 0;
    final locationCount = _roomLocationCounts[room.id] ?? 0;
    String subtitle = '$containerCount Container';
    if (locationCount > 0) {
      subtitle = '$locationCount Orte · $containerCount Container';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 20,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => ContainerListScreen(pb: widget.pb, room: room)));
            _refreshRooms();
          },
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(room.iconData, color: Theme.of(context).colorScheme.primary, size: 28),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz),
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
                const Spacer(),
                Text(room.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(180), fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddRoomDialog(BuildContext context, {Room? room}) {
    showDialog(
      context: context,
      builder: (context) => InventoryForm(
        title: room == null ? 'Neuer Raum' : 'Raum bearbeiten',
        initialName: room?.name,
        initialIcon: room?.iconName ?? 'meeting_room',
        showIcons: true,
        availableIcons: const ['meeting_room', 'kitchen', 'garage', 'weekend', 'bed', 'build', 'warehouse', 'deck'],
        pb: widget.pb,
        onSave: (name, quantity, imageFile, icon, labelId) async {
          final data = {'name': name, 'icon': icon};
          try {
            if (room == null) {
              await widget.pb.collection('rooms').create(body: data);
            } else {
              await widget.pb.collection('rooms').update(room.id, body: data);
            }
            if (context.mounted) Navigator.pop(context);
            _refreshRooms();
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
          }
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Room room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await widget.pb.collection('rooms').delete(room.id);
              if (context.mounted) {
                nav.pop();
                _refreshRooms();
              }
            }, 
            child: const Text('Löschen', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}
