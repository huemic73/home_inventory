import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';

class MoveContainerScreen extends StatefulWidget {
  final PocketBase pb;
  final InventoryContainer container;

  const MoveContainerScreen({super.key, required this.pb, required this.container});

  @override
  State<MoveContainerScreen> createState() => _MoveContainerScreenState();
}

class _MoveContainerScreenState extends State<MoveContainerScreen> {
  late Future<List<Room>> _roomsFuture;
  String? _selectedRoomId;
  List<StorageLocation>? _locations;
  String? _selectedLocationId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _roomsFuture = _fetchRooms();
    _selectedRoomId = widget.container.roomId;
    _selectedLocationId = widget.container.storageLocationId;
    if (_selectedRoomId != null) {
      _fetchLocations(_selectedRoomId!);
    }
  }

  Future<List<Room>> _fetchRooms() async {
    final records = await widget.pb.collection('rooms').getFullList(sort: 'name');
    return records.map((r) => Room.fromRecord(r)).toList();
  }

  Future<void> _fetchLocations(String roomId) async {
    final records = await widget.pb.collection('storage_locations').getFullList(
      filter: 'room = "$roomId"',
      sort: 'name',
    );
    setState(() {
      _locations = records.map((r) => StorageLocation.fromRecord(r)).toList();
    });
  }

  Future<void> _saveMove() async {
    if (_selectedRoomId == null) return;

    setState(() => _isSaving = true);
    try {
      await widget.pb.collection('containers').update(
        widget.container.id,
        body: {
          'room': _selectedRoomId,
          'storage_location': _selectedLocationId?.isEmpty == true ? null : _selectedLocationId,
        },
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
        title: const Text('Container verschieben', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  Text('Verschiebe Container:', style: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(150), fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(widget.container.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            _buildSectionTitle('1. Ziel-Raum wählen'),
            FutureBuilder<List<Room>>(
              future: _roomsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final rooms = snapshot.data!;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(border: InputBorder.none),
                    value: _selectedRoomId,
                    items: rooms.map((r) => DropdownMenuItem(value: r.id, child: Row(children: [Icon(r.iconData, size: 20), const SizedBox(width: 12), Text(r.name)]))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedRoomId = val;
                        _selectedLocationId = null;
                        _locations = null;
                      });
                      if (val != null) _fetchLocations(val);
                    },
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            _buildSectionTitle('2. Ablageort (optional)'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _selectedRoomId == null ? Colors.grey.withAlpha(10) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(border: InputBorder.none),
                value: _selectedLocationId,
                hint: const Text('Direkt im Raum (kein spezieller Ort)'),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Direkt im Raum')),
                  ...?_locations?.map((l) => DropdownMenuItem(value: l.id, child: Row(children: [Icon(l.iconData, size: 20), const SizedBox(width: 12), Text(l.name)]))),
                ],
                onChanged: _selectedRoomId == null ? null : (val) => setState(() => _selectedLocationId = val),
              ),
            ),
            
            const SizedBox(height: 48),
            
            FilledButton(
              onPressed: (_selectedRoomId == null || _isSaving) ? null : _saveMove,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Verschieben bestätigen', style: TextStyle(fontWeight: FontWeight.bold)),
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
