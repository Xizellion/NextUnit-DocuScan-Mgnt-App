import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> recognizeTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  /// Parses extracted OCR text lines into structured 2D tabular rows
  /// Supports CSV-like delimiter splitting or space/tab aligned columns
  List<List<String>> parseTextToTable(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    List<List<String>> table = [];

    for (var line in lines) {
      List<String> cells = [];

      // Check if line contains comma, tab, or pipe delimiters
      if (line.contains(',')) {
        cells = line.split(',').map((c) => c.trim()).toList();
      } else if (line.contains('\t')) {
        cells = line.split('\t').map((c) => c.trim()).toList();
      } else if (line.contains('|')) {
        cells = line
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
      } else if (line.contains(';') && line.split(';').length > 1) {
        cells = line.split(';').map((c) => c.trim()).toList();
      } else {
        // Multi-space separated columns or standard words
        cells = line
            .split(RegExp(r'\s{2,}|\s+-\s+'))
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();

        // If line is just single spaces, treat whole line or word chunks
        if (cells.length <= 1 && line.contains(' ')) {
          final words = line.split(' ').where((w) => w.trim().isNotEmpty).toList();
          if (words.length >= 2 && words.length <= 6) {
            cells = words;
          } else {
            cells = [line];
          }
        }
      }

      if (cells.isNotEmpty) {
        table.add(cells);
      }
    }

    return table;
  }

  void dispose() {
    _textRecognizer.close();
  }
}