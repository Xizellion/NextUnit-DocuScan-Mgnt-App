import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'models/document_model.dart';
import 'services/drive_service.dart';
import 'services/excel_export_service.dart';
import 'services/ocr_service.dart';
import 'services/pdf_service.dart';
import 'services/storage_service.dart';
import 'services/voice_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const NextUnitDocuScanApp());
}

class NextUnitDocuScanApp extends StatelessWidget {
  const NextUnitDocuScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextUnit DocuScan App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F62FE),
          primary: const Color(0xFF0F62FE),
          secondary: const Color(0xFF0043CE),
          surface: const Color(0xFFF4F7FB),
          surfaceContainer: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF161616),
        ),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;

  final OcrService _ocrService = OcrService();
  final SpreadsheetService _spreadsheetService = SpreadsheetService();
  final PdfService _pdfService = PdfService();
  final StorageService _storageService = StorageService();
  final VoiceService _voiceService = VoiceService();
  final DriveService _driveService = DriveService();
  final ImagePicker _picker = ImagePicker();

  // App State
  File? _scannedImageFile;
  String _extractedText = '';
  String _currentDocTitle = 'Scanned_Doc';
  bool _isProcessingOcr = false;
  List<List<String>> _tableRows = [];

  // Scanned Documents Storage
  final List<DocumentItem> _documents = [];
  String _selectedFilter = 'all';

  @override
  void dispose() {
    _ocrService.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  // --- Document Scanner & OCR Methods ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        final docTitle = 'Doc_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
        setState(() {
          _scannedImageFile = File(pickedFile.path);
          _isProcessingOcr = true;
          _extractedText = '';
          _currentDocTitle = docTitle;
          _tableRows = [];
        });

        final text = await _ocrService.recognizeTextFromImage(_scannedImageFile!);
        final table = _ocrService.parseTextToTable(text);

        setState(() {
          _extractedText = text.isEmpty ? 'No text detected in this document.' : text;
          _tableRows = table;
          _isProcessingOcr = false;
        });

        if (text.isNotEmpty) {
          final newDoc = DocumentItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: docTitle,
            imagePath: pickedFile.path,
            extractedText: text,
            createdAt: DateTime.now(),
            tableData: table,
          );
          setState(() {
            _documents.insert(0, newDoc);
          });
        }
      }
    } catch (e) {
      setState(() => _isProcessingOcr = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning image: $e')),
        );
      }
    }
  }

  // --- Save as PDF to Local Storage ---
  Future<void> _saveAsPdf() async {
    if (_extractedText.isEmpty && _scannedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No scanned content available to generate PDF.')),
      );
      return;
    }

    try {
      final pdfFile = await _pdfService.generateAndSavePdf(
        title: _currentDocTitle,
        imagePath: _scannedImageFile?.path,
        ocrText: _extractedText,
        tableData: _tableRows.isNotEmpty ? _tableRows : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF107C41),
            content: Text('Saved PDF locally: ${pdfFile.path.split('/').last}'),
            action: SnackBarAction(
              label: 'Read / Open',
              textColor: Colors.white,
              onPressed: () => _pdfService.openLocalPdf(pdfFile.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save PDF: $e')),
        );
      }
    }
  }

  // --- Excel & CSV Export Methods ---
  Future<void> _exportToSpreadsheet(bool isExcel) async {
    if (_tableRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tabular data found to export.')),
      );
      return;
    }

    try {
      final fileName = 'DocuScan_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      File exportedFile;

      if (isExcel) {
        exportedFile = await _spreadsheetService.exportToExcel(
          fileName: fileName,
          tableData: _tableRows,
        );
      } else {
        exportedFile = await _spreadsheetService.exportToCsv(
          fileName: fileName,
          tableData: _tableRows,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported successfully: ${exportedFile.path.split('/').last}'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => _spreadsheetService.shareFile(exportedFile.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e')),
        );
      }
    }
  }

  // --- Open Document Details Modal / BottomSheet ---
  void _openDocumentReader({
    required String title,
    required String filePath,
    String? ocrText,
    List<List<String>>? tableData,
    String? imagePath,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Modal Grab Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.picture_as_pdf, color: Colors.red.shade700, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Local File: ${filePath.split('/').last}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Action Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open Native'),
                      onPressed: () => _pdfService.openLocalPdf(filePath),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Print'),
                      onPressed: () => _pdfService.printLocalPdf(File(filePath)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                      onPressed: () => _pdfService.shareLocalPdf(filePath),
                    ),
                  ],
                ),
              ),

              // Scrollable Reader Content
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (imagePath != null && File(imagePath).existsSync()) ...[
                      const Text(
                        'ORIGINAL SCANNED DOCUMENT',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(imagePath),
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (ocrText != null && ocrText.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'RECOGNIZED OCR TEXT',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: ocrText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('OCR Text copied')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: SelectableText(
                          ocrText,
                          style: const TextStyle(fontSize: 13, height: 1.4, fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (tableData != null && tableData.isNotEmpty) ...[
                      const Text(
                        'EXTRACTED DATA MATRIX',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                          columns: List.generate(
                            tableData.first.length,
                            (index) => DataColumn(
                              label: Text('Col ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          rows: tableData.map((row) {
                            return DataRow(
                              cells: row.map((cell) => DataCell(Text(cell))).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.document_scanner, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NextUnit DocuScan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'OCR • PDF Storage • Excel • Voice • Drive',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Google Drive Sync',
            icon: Icon(
              _driveService.isSignedIn ? Icons.cloud_done : Icons.cloud_queue,
              color: _driveService.isSignedIn ? Colors.green : Colors.grey,
            ),
            onPressed: () async {
              if (!_driveService.isSignedIn) {
                final signedIn = await _driveService.signInWithGoogle();
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(signedIn ? 'Connected to Google Drive' : 'Sign-in cancelled'),
                    ),
                  );
                }
              } else {
                await _driveService.signOut();
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildScannerTab(),
          _buildExcelTab(),
          _buildVoiceRecorderTab(),
          _buildStorageTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.scanner_outlined),
            selectedIcon: Icon(Icons.scanner),
            label: 'Scan & OCR',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_chart_outlined),
            selectedIcon: Icon(Icons.table_chart),
            label: 'Scan to Excel',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none_outlined),
            selectedIcon: Icon(Icons.mic),
            label: 'Voice Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Storage & Drive',
          ),
        ],
      ),
    );
  }

  // --- TAB 1: Document & OCR Scanner ---
  Widget _buildScannerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action Buttons: Camera & Gallery
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera Scan'),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('From Gallery'),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Image Preview Container
          if (_scannedImageFile != null) ...[
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(_scannedImageFile!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // OCR Results Section
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Extracted OCR Text',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (_extractedText.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: 'Copy Text',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _extractedText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Text copied to clipboard')),
                            );
                          },
                        ),
                    ],
                  ),
                  const Divider(),
                  if (_isProcessingOcr)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Recognizing text with ML Kit OCR...'),
                          ],
                        ),
                      ),
                    )
                  else if (_extractedText.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Scan a document or choose an image to perform OCR extraction.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    SelectableText(
                      _extractedText,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),

                  const SizedBox(height: 16),

                  // Dual Action Buttons: Save as PDF & Send to Excel
                  if (_extractedText.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('Save as PDF'),
                            onPressed: _saveAsPdf,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF107C41),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.table_chart, size: 18),
                            label: const Text('To Excel'),
                            onPressed: () => setState(() => _currentIndex = 1),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: Scan to Excel / CSV ---
  Widget _buildExcelTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF107C41), // Excel Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export Excel (.xlsx)'),
                  onPressed: () => _exportToSpreadsheet(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F62FE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.description),
                  label: const Text('Export CSV (.csv)'),
                  onPressed: () => _exportToSpreadsheet(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Spreadsheet Data Grid Preview
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Parsed Spreadsheet Grid',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${_tableRows.length} Rows',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_tableRows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No parsed table rows. Scan a document with tabular content or receipts.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                        columns: List.generate(
                          _tableRows.first.length,
                          (index) => DataColumn(
                            label: Text(
                              'Column ${index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        rows: _tableRows.map((row) {
                          return DataRow(
                            cells: row.map((cell) => DataCell(Text(cell))).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: Voice Recording & Audio Notes ---
  String? _recordedVoicePath;
  bool _isVoiceRecording = false;

  Widget _buildVoiceRecorderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (!_isVoiceRecording) {
                        final path = await _voiceService.startRecording();
                        if (path != null) {
                          setState(() {
                            _isVoiceRecording = true;
                            _recordedVoicePath = path;
                          });
                        }
                      } else {
                        final path = await _voiceService.stopRecording();
                        setState(() {
                          _isVoiceRecording = false;
                          _recordedVoicePath = path;
                        });
                      }
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isVoiceRecording ? Colors.red : Theme.of(context).colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: (_isVoiceRecording ? Colors.red : Theme.of(context).colorScheme.primary)
                                .withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isVoiceRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isVoiceRecording ? 'Recording in progress...' : 'Tap to Record Voice Note',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: _isVoiceRecording ? Colors.red : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Attach audio explanations or meeting notes to your scanned documents',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_recordedVoicePath != null) ...[
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F1FE),
                  child: Icon(Icons.audiotrack, color: Color(0xFF0F62FE)),
                ),
                title: Text(
                  _recordedVoicePath!.split('/').last,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: const Text('Audio Note • M4A / AAC Format'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_voiceService.isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        if (_voiceService.isPlaying) {
                          _voiceService.pauseAudio();
                        } else {
                          _voiceService.playAudio(_recordedVoicePath!, onComplete: () => setState(() {}));
                        }
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 20),
                      onPressed: () => Share.shareXFiles([XFile(_recordedVoicePath!)]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- TAB 4: Local Storage Access & Google Drive ---
  Widget _buildStorageTab() {
    return FutureBuilder<List<LocalFileItem>>(
      future: _storageService.getLocalDocumentFiles(),
      builder: (context, snapshot) {
        final allFiles = snapshot.data ?? [];
        final filteredFiles = allFiles.where((f) {
          if (_selectedFilter == 'pdf') return f.isPdf;
          if (_selectedFilter == 'excel') return f.isExcel || f.isCsv;
          if (_selectedFilter == 'audio') return f.isAudio;
          return true;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Google Drive Status Card
            Card(
              elevation: 0,
              color: _driveService.isSignedIn ? const Color(0xFFE6F4EA) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _driveService.isSignedIn ? const Color(0xFF34A853) : Colors.grey.shade200,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.add_to_drive, color: Color(0xFF4285F4), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _driveService.isSignedIn
                                ? 'Connected to Google Drive'
                                : 'Google Drive Backup & Sync',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _driveService.isSignedIn
                                ? (_driveService.currentUser?.email ?? 'Sync active')
                                : 'Sign in to automatically sync scans & sheets',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (!_driveService.isSignedIn) {
                          await _driveService.signInWithGoogle();
                        } else {
                          await _driveService.signOut();
                        }
                        setState(() {});
                      },
                      child: Text(_driveService.isSignedIn ? 'Disconnect' : 'Connect'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Import Document Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.file_open),
              label: const Text('Pick & Read Local PDF / Document'),
              onPressed: () async {
                final file = await _storageService.pickAndImportLocalDocument();
                if (file != null) {
                  setState(() {});
                  if (mounted) {
                    _openDocumentReader(
                      title: file.path.split('/').last,
                      filePath: file.path,
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Files'),
                    selected: _selectedFilter == 'all',
                    onSelected: (val) => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('PDFs (.pdf)'),
                    selected: _selectedFilter == 'pdf',
                    onSelected: (val) => setState(() => _selectedFilter = 'pdf'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Sheets (.xlsx / .csv)'),
                    selected: _selectedFilter == 'excel',
                    onSelected: (val) => setState(() => _selectedFilter = 'excel'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Audio (.m4a)'),
                    selected: _selectedFilter == 'audio',
                    onSelected: (val) => setState(() => _selectedFilter = 'audio'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Local Storage Archives',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${filteredFiles.length} files',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (filteredFiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No local files found in this category. Scanned docs and exports will appear here.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...filteredFiles.map((item) {
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    onTap: () {
                      _openDocumentReader(
                        title: item.name,
                        filePath: item.path,
                        ocrText: item.isPdf ? _extractedText : null,
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: item.isPdf
                          ? Colors.red.shade50
                          : item.isExcel
                              ? const Color(0xFFE6F4EA)
                              : item.isCsv
                                  ? const Color(0xFFE8F1FE)
                                  : const Color(0xFFFFF3E0),
                      child: Icon(
                        item.isPdf
                            ? Icons.picture_as_pdf
                            : item.isExcel
                                ? Icons.table_view
                                : item.isCsv
                                    ? Icons.description
                                    : item.isAudio
                                        ? Icons.mic
                                        : Icons.insert_drive_file,
                        color: item.isPdf
                            ? Colors.red.shade700
                            : item.isExcel
                                ? const Color(0xFF137333)
                                : item.isCsv
                                    ? const Color(0xFF1A73E8)
                                    : Colors.orange.shade800,
                        size: 20,
                      ),
                    ),
                    title: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${item.formattedSize} • ${DateFormat('MMM d, HH:mm').format(item.modifiedAt)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                          tooltip: 'Upload to Google Drive',
                          onPressed: () async {
                            final fileId = await _driveService.uploadFileToDrive(File(item.path));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(fileId != null
                                      ? 'Uploaded to Drive ($fileId)'
                                      : 'Drive upload complete'),
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, size: 20),
                          onPressed: () => Share.shareXFiles([XFile(item.path)]),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}