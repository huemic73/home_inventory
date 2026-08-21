import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models.dart';
import 'ui_components.dart';

class BulkQrPrintScreen extends StatefulWidget {
  final PocketBase pb;
  const BulkQrPrintScreen({super.key, required this.pb});

  @override
  State<BulkQrPrintScreen> createState() => _BulkQrPrintScreenState();
}

class _BulkQrPrintScreenState extends State<BulkQrPrintScreen> {
  List<StorageNode> _allContainers = [];
  List<StorageNode> _filteredContainers = [];
  final Set<String> _selectedIds = {};
  NodeType? _selectedTypeFilter;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContainers();
  }

  Future<void> _loadContainers() async {
    final records = await widget.pb.collection('nodes').getFullList(
      filter: 'type = "container" || type = "ablageort"',
      sort: 'name', 
      expand: 'parent.parent.parent.parent.parent'
    );
    setState(() {
      _allContainers = records.map((r) => StorageNode.fromRecord(r)).toList();
      _selectedIds.addAll(_allContainers.map((c) => c.id));
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredContainers = _allContainers.where((c) {
        return _selectedTypeFilter == null || c.type == _selectedTypeFilter;
      }).toList();
    });
  }

  List<StorageNode> _extractBreadcrumbs(StorageNode node) {
    final List<StorageNode> path = [];
    var parentList = node.record.expand['parent'];
    var parent = parentList != null && parentList.isNotEmpty ? parentList.first : null;
    while (parent != null) {
      path.add(StorageNode.fromRecord(parent));
      parentList = parent.expand['parent'];
      parent = parentList != null && parentList.isNotEmpty ? parentList.first : null;
    }
    return path.reversed.toList();
  }

  String _getPathString(List<StorageNode> path) {
    if (path.isEmpty) return '';
    return path.map((n) => n.name).join(' › ');
  }

  Widget _buildFilterChip(NodeType? type, String label) {
    final isSelected = _selectedTypeFilter == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primary,
      onSelected: (val) {
        _selectedTypeFilter = type;
        _applyFilters();
      },
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(
        color: isSelected 
            ? Theme.of(context).colorScheme.primary 
            : (isDark ? Colors.white12 : Colors.grey.withAlpha(50))
      ),
    );
  }

  Future<void> _generateAndPrint() async {
    try {
      final font = await PdfGoogleFonts.outfitRegular();
      final boldFont = await PdfGoogleFonts.outfitBold();
      final doc = pw.Document();
      final containersToPrint = _allContainers.where((c) => _selectedIds.contains(c.id)).toList();

      final Map<String, List<StorageNode>> grouped = {};
      for (var c in containersToPrint) {
        final parentRecord = c.record.get<RecordModel?>('expand.parent');
        String pathStr = 'Hauptebene';
        if (parentRecord != null) {
          final parentNode = StorageNode.fromRecord(parentRecord);
          final parentPath = _extractBreadcrumbs(parentNode);
          final fullParentPath = [...parentPath, parentNode];
          pathStr = _getPathString(fullParentPath);
        }
        grouped.putIfAbsent(pathStr, () => []).add(c);
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            List<pw.Widget> widgets = [
              pw.Header(level: 0, text: 'Heiminventarisierung - Inventurliste', textStyle: pw.TextStyle(font: boldFont, fontSize: 18)),
              pw.SizedBox(height: 20),
            ];

            grouped.forEach((groupName, containers) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  child: pw.Text('Standort: $groupName', style: pw.TextStyle(fontSize: 14, font: boldFont, color: PdfColors.indigo900)),
                ),
              );

              widgets.add(
                pw.Wrap(
                  spacing: 15, runSpacing: 15,
                  children: containers.map((container) {
                    final String qrData = '$qrBaseUrl/c/${container.id}';

                    return pw.Container(
                      width: 140, height: 170,
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(container.name, style: pw.TextStyle(fontSize: 9, font: boldFont), textAlign: pw.TextAlign.center, maxLines: 2),
                          pw.SizedBox(height: 10),
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high), 
                            data: qrData, 
                            width: 75, height: 75
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text('ID: ${container.id.substring(0, 8)}', style: pw.TextStyle(fontSize: 6, font: font, color: PdfColors.grey600)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
              widgets.add(pw.SizedBox(height: 20));
              widgets.add(pw.Divider(thickness: 0.5, color: PdfColors.grey300));
            });
            return widgets;
          },
        ),
      );
      await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Inventur_Struktur.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Druckfehler: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InventoryPageLayout(
      title: 'Labels drucken',
      subtitle: 'QR-Codes für deine Orte & Boxen',
      slivers: [
        if (!_isLoading) ...[
          // Filter Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  _buildFilterChip(null, 'Alles'),
                  const SizedBox(width: 8),
                  _buildFilterChip(NodeType.ablageort, 'Ablageorte'),
                  const SizedBox(width: 8),
                  _buildFilterChip(NodeType.container, 'Container'),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Text(
                      '${_selectedIds.length} gewählt',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _selectedIds.removeAll(_filteredContainers.map((c) => c.id))), 
                      child: const Text('Keine')
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () => setState(() => _selectedIds.addAll(_filteredContainers.map((c) => c.id))), 
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
        ],
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
                  final container = _filteredContainers[index];
                  final isSelected = _selectedIds.contains(container.id);
                  final containerPath = _extractBreadcrumbs(container);
                  final pathStr = _getPathString(containerPath);
                  String imageUrl = '';
                  if (container.photo.isNotEmpty) {
                    imageUrl = widget.pb.files.getUrl(container.record, container.photo).toString();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).cardTheme.color : Theme.of(context).cardTheme.color?.withAlpha(150),
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
                            if (val == true) {
                              _selectedIds.add(container.id);
                            } else {
                              _selectedIds.remove(container.id);
                            }
                          });
                        },
                        title: Text(container.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${container.id.substring(0, 8)}...', style: const TextStyle(fontSize: 11)),
                            if (pathStr.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                pathStr, 
                                style: TextStyle(
                                  fontSize: 11, 
                                  color: Theme.of(context).colorScheme.primary.withAlpha(200),
                                ),
                              ),
                            ],
                          ],
                        ),
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
                                ? InventoryNetworkImage(imageUrl: imageUrl, title: container.name)
                                : Icon(container.iconData, color: Theme.of(context).colorScheme.primary.withAlpha(100)),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _filteredContainers.length,
              ),
            ),
          ),
      ],
      floatingActionButton: _selectedIds.isNotEmpty 
          ? FloatingActionButton.extended(
              onPressed: _generateAndPrint,
              icon: const Icon(Icons.print),
              label: Text('${_selectedIds.length} Labels drucken'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            )
          : null,
    );
  }
}
