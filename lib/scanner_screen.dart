import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'item_list_screen.dart';

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
      if (code == null || !code.startsWith('home_inventory_container:')) continue;

      setState(() => _isProcessed = true);
      final scannedId = code.replaceFirst('home_inventory_container:', '');

      if (widget.isAssigningMode) {
        // Wir sind im Zuweisungsmodus -> ID zurückgeben an den vorherigen Screen
        Navigator.pop(context, scannedId);
        return;
      }

      _openContainer(scannedId);
      break;
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
