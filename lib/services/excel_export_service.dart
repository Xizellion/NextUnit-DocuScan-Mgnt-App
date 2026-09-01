import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SpreadsheetService {
  /// Exports table rows to an Excel (.xlsx) file
  Future<File> exportToExcel({
    required String fileName,
    required List<List<String>> tableData,
    String sheetName = 'ScannedData',
  }) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel[sheetName];

    if (sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.blue400,
      fontColorHex: ExcelColor.white,
    );

    for (int r = 0; r < tableData.length; r++) {
      final row = tableData[r];
      for (int c = 0; c < row.length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        );
        cell.value = TextCellValue(row[c]);
        if (r == 0) {
          cell.cellStyle = headerStyle;
        }
      }
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filePath = '${outputDir.path}/$cleanName.xlsx';
    final file = File(filePath);

    final fileBytes = excel.save();
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes, flush: true);
    }

    return file;
  }

  /// Exports table rows to a standard CSV (.csv) file
  Future<File> exportToCsv({
    required String fileName,
    required List<List<String>> tableData,
  }) async {
    final csvString = const ListToCsvConverter().convert(tableData);
    final outputDir = await getApplicationDocumentsDirectory();
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final filePath = '${outputDir.path}/$cleanName.csv';
    final file = File(filePath);

    await file.writeAsString(csvString, flush: true);
    return file;
  }

  /// Share file via system share dialog
  Future<void> shareFile(String filePath, {String? text}) async {
    final xFile = XFile(filePath);
    await Share.shareXFiles([xFile], text: text ?? 'Exported from NextUnit DocuScan App');
  }
}