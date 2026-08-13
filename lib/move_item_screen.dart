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
    // Alle Räume holen
    final roomRecords = await widget.pb.collection('rooms').getFullList(sort: 'name');
    final allRooms = roomRecords.map((r) => Room.fromRecord(r)).toList();

    // Alle Container holen, um zu sehen, welche Räume belegt sind
    final containerRecords = await widget.pb.collection('containers').getFullList(fields: 'room');
    final Set<String> roomIdsWithContainers = containerRecords
        .map((c) => c.getStringValue('room'))
        .where((id) => id.isNotEmpty)
        .toSet();

    // Nur Räume zurückgeben, die mindestens einen Container haben
    return allRooms.where((room) => roomIdsWithContainers.contains(room.id)).toList();
  }

  Future<void> _fetchContainers(String roomId) async {
    final records = await widget.pb.collection('containers').getFullList(
      filter: 'room = "$roomId"',
      sort: 'name',
    );
    setState(() {
      _containers = records.map((r) => InventoryContainer.fromRecord(r)).toList();
      _selectedContainerId = null;
    });
  }

  Future<void> _saveMove() async {
    setState(() => _isSaving = true);
    try {
      await widget.pb.collection('items').update(
        widget.item.id,
        body: {'container': _selectedContainerId},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Verschieben', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wohin soll', style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(150), fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(widget.item.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('verschoben werden?'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            _buildSectionTitle('1. Raum wählen'),
            FutureBuilder<List<Room>>(
              future: _roomsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final rooms = snapshot.data!;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true, // Wichtig für breite Texte
                    decoration: const InputDecoration(border: InputBorder.none),
                    value: _selectedRoomId,
                    hint: const Text('Raum auswählen'),
                    items: rooms.map((r) => DropdownMenuItem(
                      value: r.id, 
                      child: Row(
                        children: [
                          Icon(r.iconData, size: 20), 
                          const SizedBox(width: 12), 
                          Expanded(child: Text(r.name, overflow: TextOverflow.ellipsis))
                        ]
                      )
                    )).toList(),
                    onChanged: (val) {
                      setState(() => _selectedRoomId = val);
                      if (val != null) _fetchContainers(val);
                    },
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            _buildSectionTitle('2. Container wählen'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _selectedRoomId == null ? Colors.grey.withAlpha(10) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonFormField<String>(
                isExpanded: true, // Wichtig für breite Texte
                decoration: const InputDecoration(border: InputBorder.none),
                value: _selectedContainerId,
                disabledHint: const Text('Zuerst Raum wählen'),
                hint: const Text('Box / Regal wählen'),
                items: _containers?.map((c) => DropdownMenuItem(
                  value: c.id, 
                  child: Row(
                    children: [
                      Icon(c.iconData, size: 20), 
                      const SizedBox(width: 12), 
                      Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis))
                    ]
                  )
                )).toList() ?? [],
                onChanged: _selectedRoomId == null ? null : (val) => setState(() => _selectedContainerId = val),
              ),
            ),
            
            const SizedBox(height: 48),
            
            FilledButton(
              onPressed: (_selectedContainerId == null || _isSaving) ? null : _saveMove,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Verschieben bestätigen', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSaving ? null : () {
                setState(() { _selectedContainerId = null; _selectedRoomId = null; _containers = null; });
                _saveMove();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                side: BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(50)),
              ),
              child: const Text('Als "lose" markieren'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}
