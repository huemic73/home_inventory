import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models.dart';

class QrDisplayScreen extends StatelessWidget {
  final InventoryContainer? container;
  final Item? item;

  const QrDisplayScreen({super.key, this.container, this.item})
      : assert(container != null || item != null);

  String get _name => container?.name ?? item?.name ?? 'Unbekannt';
  String get _id => container?.id ?? item?.id ?? '';
  String get _type => container != null ? 'container' : 'item';
  String get _qrData => 'home_inventory_$_type:$_id';

  Future<void> _printQrCode(BuildContext context) async {
    try {
      final doc = pw.Document();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('Home Inventory', style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.Text(_name, style: pw.TextStyle(fontSize: 30)),
                  pw.SizedBox(height: 10),
                  pw.Text(_type == 'container' ? 'Container / Box' : 'Artikel', style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
                  pw.SizedBox(height: 40),
                  pw.Container(
                    width: 300,
                    height: 300,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: _qrData,
                      width: 300,
                      height: 300,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text('ID: $_id', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'QR_${_type}_${_name.replaceAll(' ', '_')}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Druckfehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR-Code: $_name'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Diesen Code auf den ${_type == 'container' ? 'Behälter' : 'Artikel'} kleben.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 40),
                
                Container(
                  width: 280,
                  height: 280,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5),
                    ],
                  ),
                  child: PrettyQrView.data(
                    data: _qrData,
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(color: Colors.black),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                Text(_name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text(_type == 'container' ? 'Container' : 'Einzelner Artikel', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                
                const SizedBox(height: 60),
                
                FilledButton.icon(
                  onPressed: () => _printQrCode(context),
                  icon: const Icon(Icons.print),
                  label: const Text('Drucken / Als PDF speichern'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
