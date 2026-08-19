import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pocketbase/pocketbase.dart';
import 'models.dart';
import 'item_detail_screen.dart';
import 'container_list_screen.dart';

class ScannerScreen extends StatefulWidget {
  final PocketBase pb;
  final bool isAssigningMode;

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

      if (code.startsWith(qrBaseUrl)) {
        final uri = Uri.parse(code);
        final segments = uri.pathSegments;
        
        if (segments.length >= 2) {
          final type = segments[0]; // 'c' für container/node, 'i' für item
          final id = segments[1];

          setState(() => _isProcessed = true);

          if (widget.isAssigningMode) {
            Navigator.pop(context, id);
            return;
          }

          if (type == 'c') {
            _openNode(id);
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
      final record = await widget.pb.collection('items').getOne(id, expand: 'node');
      final item = Item.fromRecord(record);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item, pb: widget.pb)),
        );
      }
    } catch (e) {
      _resetScanner('Artikel nicht gefunden: $e');
    }
  }

  Future<void> _openNode(String id) async {
    try {
      // 1. Suche nach labelId
      var result = await widget.pb.collection('nodes').getList(
        filter: 'labelId = "$id"',
      );

      RecordModel? record;
      if (result.items.isNotEmpty) {
        record = result.items.first;
      } else {
        // 2. Suche nach DB-ID
        try {
          record = await widget.pb.collection('nodes').getOne(id);
        } catch (_) {}
      }

      if (record != null) {
        final node = StorageNode.fromRecord(record);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ContainerListScreen(pb: widget.pb, parentNode: node)),
          );
        }
      } else {
        _resetScanner('QR-Code unbekannt.');
      }
    } catch (e) {
      _resetScanner('Fehler: $e');
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
      appBar: AppBar(title: Text(widget.isAssigningMode ? 'Code scannen' : 'Inhalt scannen')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleBarcode),
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(border: Border.all(color: Colors.white.withAlpha(150), width: 2), borderRadius: BorderRadius.circular(20)),
            ),
          ),
          if (_isProcessed) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
