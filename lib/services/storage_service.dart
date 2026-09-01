import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class LocalFileItem {
  final String path;
  final String name;
  final String extension;
  final int sizeBytes;
  final DateTime modifiedAt;
  final bool isPdf;
  final bool isExcel;
  final bool isCsv;
  final bool isAudio;

  LocalFileItem({
    required this.path,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.isPdf,
    required this.isExcel,
    required this.isCsv,
    required this.isAudio,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class StorageService {
  /// Returns the local documents storage directory
  Future<Directory> getAppStorageDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Lists all locally saved PDFs, spreadsheets, and recordings
  Future<List<LocalFileItem>> getLocalDocumentFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final entities = dir.listSync();
      final List<LocalFileItem> items = [];

      for (var entity in entities) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
          final stat = entity.statSync();

          items.add(
            LocalFileItem(
              path: entity.path,
              name: name,
              extension: ext,
              sizeBytes: stat.size,
              modifiedAt: stat.modified,
              isPdf: ext == 'pdf',
              isExcel: ext == 'xlsx' || ext == 'xls',
              isCsv: ext == 'csv',
              isAudio: ext == 'm4a' || ext == 'mp3' || ext == 'aac',
            ),
          );
        }
      }

      items.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  /// Allows picking any document or PDF from external storage and imports it
  Future<File?> pickAndImportLocalDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'txt', 'jpg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        final sourceFile = File(result.files.single.path!);
        final dir = await getApplicationDocumentsDirectory();
        final fileName = result.files.single.name;
        final targetPath = '${dir.path}/$fileName';

        // Copy into local app storage
        final copiedFile = await sourceFile.copy(targetPath);
        return copiedFile;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Reads a document file as string (for CSV/TXT)
  Future<String?> readDocumentAsString(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Reads a document file as raw bytes (for PDF / Images)
  Future<Uint8List?> readDocumentAsBytes(String filePath) async {
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

  /// Deletes a file from local storage
  Future<bool> deleteLocalFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}