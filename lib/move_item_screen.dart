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
  late Future<List<StorageNode>> _nodesFuture;
  String? _selectedNodeId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nodesFuture = _fetchNodes();
    _selectedNodeId = widget.item.nodeId;
  }

  Future<List<StorageNode>> _fetchNodes() async {
    final records = await widget.pb.collection('nodes').getFullList(sort: 'name');
    return records.map((r) => StorageNode.fromRecord(r)).toList();
  }

  Future<void> _saveMove() async {
    setState(() => _isSaving = true);
    try {
      await widget.pb.collection('items').update(
        widget.item.id,
        body: {'node': _selectedNodeId ?? ''},
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
        title: const Text('Artikel verschieben'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text('Wähle einen neuen Ort für ${widget.item.name}:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            FutureBuilder<List<StorageNode>>(
              future: _nodesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final nodes = snapshot.data!;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedNodeId,
                    isExpanded: true,
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: [
                      const DropdownMenuItem<String?>(value: '', child: Text('Lose (keinem Ort zugeordnet)')),
                      ...nodes.map((n) => DropdownMenuItem<String?>(
                        value: n.id,
                        child: Text('${n.type.name.toUpperCase()}: ${n.name}')
                      )),
                    ],
                    onChanged: (val) => setState(() => _selectedNodeId = val),
                  ),
                );
              },
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveMove,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Speichern'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
