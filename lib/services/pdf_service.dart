import 'dart:io';
import 'dart:typed_data';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PdfService {
  /// Generates a structured, searchable PDF containing the scanned image,
  /// formatted OCR text, and extracted table matrix.
  /// Saves the PDF directly to device local storage.
  Future<File> generateAndSavePdf({
    required String title,
    String? imagePath,
    required String ocrText,
    List<List<String>>? tableData,
    String? customFileName,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? memoryImage;
    if (imagePath != null && File(imagePath).existsSync()) {
      final imageBytes = await File(imagePath).readAsBytes();
      memoryImage = pw.MemoryImage(imageBytes);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header with Document Title & Metadata
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'NextUnit DocuScan Archive • Digitally Processed',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateTime.now().toLocal().toString().split('.')[0],
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Embedded Scanned Image (if present)
            if (memoryImage != null) ...[
              pw.Text(
                'SCANNED DOCUMENT CAPTURE',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Container(
                  height: 240,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Image(memoryImage, fit: pw.BoxFit.contain),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Extracted Tabular Data (if present)
            if (tableData != null && tableData.isNotEmpty) ...[
              pw.Text(
                'EXTRACTED LINE ITEMS MATRIX',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                context: context,
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                border: pw.TableBorder.all(color: PdfColors.grey300),
              ),
              pw.SizedBox(height: 20),
            ],

            // OCR Searchable Text Section
            pw.Text(
              'RECOGNIZED OCR TEXT CONTENT',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                ocrText,
                style: const pw.TextStyle(
                  fontSize: 9,
                  lineSpacing: 1.4,
                  color: PdfColors.black,
                ),
              ),
            ),
          ];
        },
      ),
    );

    // Save to device local app documents directory
    final outputDir = await getApplicationDocumentsDirectory();
    final cleanName = (customFileName ?? title).replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filePath = '${outputDir.path}/$cleanName.pdf';
    final file = File(filePath);

    final bytes = await pdf.save();
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Reads a local PDF file from disk and returns raw bytes
  Future<Uint8List?> readLocalPdfBytes(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Opens the PDF file using the native device default viewer
  Future<OpenResult> openLocalPdf(String filePath) async {
    return await OpenFilex.open(filePath);
  }

  /// Prints or previews the PDF via system print service
  Future<void> printLocalPdf(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: pdfFile.path.split('/').last,
    );
  }

  /// Shares the PDF via standard system share dialog
  Future<void> shareLocalPdf(String filePath, {String? text}) async {
    final xFile = XFile(filePath);
    await Share.shareXFiles([xFile], text: text ?? 'Scanned PDF from NextUnit DocuScan App');
  }
}