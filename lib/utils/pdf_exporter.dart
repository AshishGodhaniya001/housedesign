import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class FloorPdfPage {
  final String title;
  final Uint8List imageBytes;

  const FloorPdfPage({required this.title, required this.imageBytes});
}

class PdfExporter {
  static Future<Uint8List> buildFloorPlanPdf({
    required String title,
    required List<FloorPdfPage> pages,
  }) async {
    final pdf = pw.Document();

    for (final page in pages) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  page.title,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated on ${DateTime.now()}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 16),
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(page.imageBytes),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }
}
