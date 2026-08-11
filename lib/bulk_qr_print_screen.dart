import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models.dart';

class BulkQrPrintScreen extends StatefulWidget {
  final PocketBase pb;
  const BulkQrPrintScreen({super.key, required this.pb});

  @override
  State<BulkQrPrintScreen> createState() => _BulkQrPrintScreenState();
}

class _BulkQrPrintScreenState extends State<BulkQrPrintScreen> {
  List<InventoryContainer> _allContainers = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContainers();
  }

  Future<void> _loadContainers() async {
    final records = await widget.pb.collection('containers').getFullList(sort: 'name', expand: 'room');
    setState(() {
      _allContainers = records.map((r) => InventoryContainer.fromRecord(r)).toList();
      // Standardmäßig alle auswählen
      _selectedIds.addAll(_allContainers.map((c) => c.id));
      _isLoading = false;
    });
  }

  Future<void> _generateAndPrint() async {
    final doc = pw.Document();
    final containersToPrint = _allContainers.where((c) => _selectedIds.contains(c.id)).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(level: 0, text: 'Inventar Labels'),
          pw.GridView(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: containersToPrint.map((container) {
              return pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(container.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    pw.SizedBox(height: 5),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'home_inventory_container:${container.id}',
                      width: 80,
                      height: 80,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text('ID: ${container.id}', style: const pw.TextStyle(fontSize: 6)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Container_Labels.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Labels drucken'),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(icon: const Icon(Icons.print), onPressed: _generateAndPrint),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Text('${_selectedIds.length} von ${_allContainers.length} gewählt', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: () => setState(() => _selectedIds.clear()), child: const Text('Keine')),
                      TextButton(onPressed: () => setState(() => _selectedIds.addAll(_allContainers.map((c) => c.id))), child: const Text('Alle')),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _allContainers.length,
                    itemBuilder: (context, index) {
                      final container = _allContainers[index];
                      return CheckboxListTile(
                        secondary: Icon(container.iconData),
                        title: Text(container.name),
                        subtitle: Text('ID: ${container.id}'),
                        value: _selectedIds.contains(container.id),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) _selectedIds.add(container.id);
                            else _selectedIds.remove(container.id);
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
