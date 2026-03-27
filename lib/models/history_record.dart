class HistoryRecord {
  const HistoryRecord({
    required this.id,
    required this.taskName,
    required this.pdfPath,
    required this.excelPath,
    required this.createdAt,
    required this.status,
    required this.summary,
  });

  final String id;
  final String taskName;
  final String pdfPath;
  final String excelPath;
  final String createdAt;
  final String status;
  final String summary;

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskName': taskName,
        'pdfPath': pdfPath,
        'excelPath': excelPath,
        'createdAt': createdAt,
        'status': status,
        'summary': summary,
      };

  factory HistoryRecord.fromJson(Map<String, dynamic> json) => HistoryRecord(
        id: json['id']?.toString() ?? '',
        taskName: json['taskName']?.toString() ?? '',
        pdfPath: json['pdfPath']?.toString() ?? '',
        excelPath: json['excelPath']?.toString() ?? '',
        createdAt: json['createdAt']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
      );
}
