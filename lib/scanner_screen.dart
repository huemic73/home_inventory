import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'item_list_screen.dart';
import 'item_detail_screen.dart';

class ScannerScreen extends StatefulWidget {
  final PocketBase pb;
  final bool isAssigningMode; // Neu: Falls wir nur scannen, um zuzuweisen

  const ScannerScreen({super.key, required this.pb, this.isAssigningMode = false});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isProcessed = false;

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessed) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code == null) continue;

      // Nur noch das neue URL-Format unterstützen (zentral konfiguriert)
      if (code.startsWith(qrBaseUrl)) {
        final uri = Uri.parse(code);
        final segments = uri.pathSegments;
        
        if (segments.length >= 2) {
          final type = segments[0]; // 'c' für container, 'i' für item
          final id = segments[1];

          setState(() => _isProcessed = true);

          if (widget.isAssigningMode) {
            Navigator.pop(context, id);
            return;
          }

          if (type == 'c') {
            _openContainer(id);
          } else if (type == 'i') {
            _openItem(id);
          }
          break;
        }
      }
    }
  }

  Future<void> _openItem(String id) async {
    try {
      final record = await widget.pb.collection('items').getOne(
        id, 
        expand: 'container,container.room,container.storage_location'
      );
      final item = Item.fromRecord(record);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ItemListScreen(pb: widget.pb, container: null, room: null, onlyUnassigned: false)), // Basis-Navigation
        );
        // Da wir direkt zum Item wollen, pushen wir den Detail-Screen drüber
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item, pb: widget.pb)),
        );
      }
    } catch (e) {
      _resetScanner('Artikel nicht gefunden: $e');
    }
  }

  Future<void> _openContainer(String id) async {
    try {
      // 1. Suche: Gibt es einen Container, der diese ID als manuelle 'labelId' hat?
      var result = await widget.pb.collection('containers').getList(
        filter: 'labelId = "$id"',
        expand: 'room,storage_location', // Auch Ablageort expandieren
      );

      // 2. Suche: Falls nicht gefunden, prüfe ob es die primäre Datenbank-ID ist
      if (result.items.isEmpty) {
        try {
          final record = await widget.pb.collection('containers').getOne(id, expand: 'room,storage_location');
          _navigateToItems(record);
          return;
        } catch (_) {}
      } else {
        _navigateToItems(result.items.first);
        return;
      }
      _resetScanner('Dieser QR-Code ist keiner Box zugeordnet.');
    } catch (e) {
      _resetScanner('Fehler beim Scannen: $e');
    }
  }

  void _navigateToItems(RecordModel record) {
    final container = InventoryContainer.fromRecord(record);
    Room? room;
    final roomRecord = record.get<RecordModel?>('expand.room');
    if (roomRecord != null) room = Room.fromRecord(roomRecord);
    
    StorageLocation? location;
    final locRecord = record.get<RecordModel?>('expand.storage_location');
    if (locRecord != null) {
      location = StorageLocation.fromRecord(locRecord);
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ItemListScreen(
            pb: widget.pb, 
            container: container, 
            room: room,
            storageLocation: location, // Location mitgeben
          ),
        ),
      );
    }
  }

  void _resetScanner(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _isProcessed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isAssigningMode ? 'Vorhandenen Code scannen' : 'Box scannen')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleBarcode),
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(20)),
            ),
          ),
          if (_isProcessed) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
