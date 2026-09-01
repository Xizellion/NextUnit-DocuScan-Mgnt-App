class DocumentItem {
  final String id;
  final String title;
  final String imagePath;
  final String extractedText;
  final DateTime createdAt;
  final List<List<String>> tableData;
  final String? pdfPath;
  final String? voiceNotePath;
  final int voiceDurationSec;
  final bool isSyncedToDrive;

  DocumentItem({
    required this.id,
    required this.title,
    required this.imagePath,
    required this.extractedText,
    required this.createdAt,
    this.tableData = const [],
    this.pdfPath,
    this.voiceNotePath,
    this.voiceDurationSec = 0,
    this.isSyncedToDrive = false,
  });

  DocumentItem copyWith({
    String? id,
    String? title,
    String? imagePath,
    String? extractedText,
    DateTime? createdAt,
    List<List<String>>? tableData,
    String? pdfPath,
    String? voiceNotePath,
    int? voiceDurationSec,
    bool? isSyncedToDrive,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      title: title ?? this.title,
      imagePath: imagePath ?? this.imagePath,
      extractedText: extractedText ?? this.extractedText,
      createdAt: createdAt ?? this.createdAt,
      tableData: tableData ?? this.tableData,
      pdfPath: pdfPath ?? this.pdfPath,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
      voiceDurationSec: voiceDurationSec ?? this.voiceDurationSec,
      isSyncedToDrive: isSyncedToDrive ?? this.isSyncedToDrive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imagePath': imagePath,
      'extractedText': extractedText,
      'createdAt': createdAt.toIso8601String(),
      'tableData': tableData,
      'pdfPath': pdfPath,
      'voiceNotePath': voiceNotePath,
      'voiceDurationSec': voiceDurationSec,
      'isSyncedToDrive': isSyncedToDrive,
    };
  }

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: json['id'] as String,
      title: json['title'] as String,
      imagePath: json['imagePath'] as String,
      extractedText: json['extractedText'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      tableData: (json['tableData'] as List<dynamic>?)
              ?.map((row) => (row as List<dynamic>).map((e) => e.toString()).toList())
              .toList() ??
          [],
      pdfPath: json['pdfPath'] as String?,
      voiceNotePath: json['voiceNotePath'] as String?,
      voiceDurationSec: json['voiceDurationSec'] as int? ?? 0,
      isSyncedToDrive: json['isSyncedToDrive'] as bool? ?? false,
    );
  }
}