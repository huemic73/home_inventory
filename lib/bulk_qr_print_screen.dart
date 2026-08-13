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
      _selectedIds.addAll(_allContainers.map((c) => c.id));
      _isLoading = false;
    });
  }

  Future<void> _generateAndPrint() async {
    try {
      final doc = pw.Document();
      final containersToPrint = _allContainers.where((c) => _selectedIds.contains(c.id)).toList();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            pw.Header(level: 0, text: 'Inventar Labels'),
            pw.SizedBox(height: 20),
            pw.Wrap(
              spacing: 20,
              runSpacing: 20,
              children: containersToPrint.map((container) {
                return pw.Container(
                  width: 150,
                  height: 180,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  ),
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        container.name, 
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), 
                        textAlign: pw.TextAlign.center,
                        maxLines: 2,
                      ),
                      // Neuen Ort (Raum) hinzufügen
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Ort: ${container.record.expand['room']?.first.getStringValue('name') ?? 'Unbekannt'}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 8),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'home_inventory_container:${container.id}',
                        width: 100,
                        height: 100,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('ID: ${container.id}', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(), 
        name: 'Container_Labels.pdf'
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Druckfehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withAlpha(20),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                title: Text(
                  'Labels drucken',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (!_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_selectedIds.length} gewählt',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _selectedIds.clear()), 
                          child: const Text('Keine')
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () => setState(() => _selectedIds.addAll(_allContainers.map((c) => c.id))), 
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Alle wählen')
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_allContainers.isEmpty)
              const SliverFillRemaining(child: Center(child: Text('Keine Container zum Drucken vorhanden.')))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final container = _allContainers[index];
                      final isSelected = _selectedIds.contains(container.id);
                      String imageUrl = '';
                      if (container.photo.isNotEmpty) {
                        imageUrl = widget.pb.files.getUrl(container.record, container.photo).toString();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.white.withAlpha(150),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              if (isSelected) 
                                BoxShadow(color: Theme.of(context).colorScheme.primary.withAlpha(20), blurRadius: 10, offset: const Offset(0, 4))
                              else
                                BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))
                            ],
                          ),
                          child: CheckboxListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) _selectedIds.add(container.id);
                                else _selectedIds.remove(container.id);
                              });
                            },
                            title: Text(container.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('ID: ${container.id.substring(0, 8)}...', style: const TextStyle(fontSize: 11)),
                            secondary: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withAlpha(10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(imageUrl, fit: BoxFit.cover)
                                    : Icon(container.iconData, color: Theme.of(context).colorScheme.primary.withAlpha(100)),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _allContainers.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      floatingActionButton: _selectedIds.isNotEmpty 
          ? FloatingActionButton.extended(
              onPressed: _generateAndPrint,
              icon: const Icon(Icons.print),
              label: Text('${_selectedIds.length} Labels drucken'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
