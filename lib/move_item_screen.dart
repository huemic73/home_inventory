import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';

class MoveItemScreen extends StatefulWidget {
  final PocketBase pb;
  final Item item;

  const MoveItemScreen({super.key, required this.pb, required this.item});

  @override
  State<MoveItemScreen> createState() => _MoveItemScreenState();
}

class _MoveItemScreenState extends State<MoveItemScreen> {
  late Future<List<Room>> _roomsFuture;
  String? _selectedRoomId;
  List<InventoryContainer>? _containers;
  String? _selectedContainerId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _roomsFuture = _fetchRooms();
  }

  Future<List<Room>> _fetchRooms() async {
    final records = await widget.pb.collection('rooms').getFullList(sort: 'name');
    return records.map((r) => Room.fromRecord(r)).toList();
  }

  Future<void> _fetchContainers(String roomId) async {
    final records = await widget.pb.collection('containers').getFullList(
      filter: 'room = "$roomId"',
      sort: 'name',
    );
    setState(() {
      _containers = records.map((r) => InventoryContainer.fromRecord(r)).toList();
      _selectedContainerId = null; // Zurücksetzen bei Raumwechsel
    });
  }

  Future<void> _saveMove() async {
    setState(() => _isSaving = true);
    try {
      await widget.pb.collection('items').update(
        widget.item.id,
        body: {'container': _selectedContainerId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gegenstand erfolgreich verschoben!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gegenstand verschieben'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Wohin soll "${widget.item.name}" verschoben werden?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            
            // Raum Auswahl
            FutureBuilder<List<Room>>(
              future: _roomsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final rooms = snapshot.data!;
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Raum auswählen',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedRoomId,
                  items: rooms.map((r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(r.name),
                  )).toList(),
                  onChanged: (val) {
                    setState(() => _selectedRoomId = val);
                    if (val != null) _fetchContainers(val);
                  },
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Container Auswahl
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Container / Box auswählen',
                border: OutlineInputBorder(),
                hintText: 'Zuerst Raum wählen',
              ),
              value: _selectedContainerId,
              items: _containers?.map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(c.name),
              )).toList() ?? [],
              onChanged: _selectedRoomId == null ? null : (val) {
                setState(() => _selectedContainerId = val);
              },
            ),
            
            const Spacer(),
            
            FilledButton.icon(
              onPressed: (_selectedContainerId == null || _isSaving) ? null : _saveMove,
              icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.drive_file_move),
              label: const Text('Verschieben bestätigen'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                // Optionale Logik: In "Kein Container" (lose) verschieben
                setState(() {
                  _selectedContainerId = null;
                  _selectedRoomId = null;
                  _containers = null;
                });
                _saveMove();
              },
              child: const Text('Als "lose" markieren (Kein Container)'),
            ),
          ],
        ),
      ),
    );
  }
}
