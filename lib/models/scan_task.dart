import 'ai_check_result.dart';

enum TaskStatus {
  pending,
  scanning,
  scanned,
  queued,
  checking,
  done,
  failed,
}

extension TaskStatusX on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.pending:
        return '待处理';
      case TaskStatus.scanning:
        return '扫描中';
      case TaskStatus.scanned:
        return '已扫描';
      case TaskStatus.queued:
        return '排队中';
      case TaskStatus.checking:
        return '核验中';
      case TaskStatus.done:
        return '已完成';
      case TaskStatus.failed:
        return '失败';
    }
  }
}

class ScanTask {
  const ScanTask({
    required this.rowIndex,
    required this.taskName,
    required this.pdfFileNameStem,
    required this.rowData,
    this.status = TaskStatus.pending,
    this.imagePaths = const [],
    this.pdfPath,
    this.aiResult,
    this.errorMessage,
    this.createdAt,
  });

  final int rowIndex;
  final String taskName;
  final String pdfFileNameStem;
  final Map<String, String> rowData;
  final TaskStatus status;
  final List<String> imagePaths;
  final String? pdfPath;
  final AiCheckResult? aiResult;
  final String? errorMessage;
  final DateTime? createdAt;

  bool get canStartChecking =>
      imagePaths.isNotEmpty &&
      (status == TaskStatus.scanned || status == TaskStatus.failed);

  bool get isInFlight =>
      status == TaskStatus.queued || status == TaskStatus.checking;

  ScanTask copyWith({
    TaskStatus? status,
    List<String>? imagePaths,
    String? pdfPath,
    AiCheckResult? aiResult,
    String? errorMessage,
    bool clearPdfPath = false,
    bool clearAiResult = false,
    bool clearError = false,
    DateTime? createdAt,
  }) {
    return ScanTask(
      rowIndex: rowIndex,
      taskName: taskName,
      pdfFileNameStem: pdfFileNameStem,
      rowData: rowData,
      status: status ?? this.status,
      imagePaths: imagePaths ?? this.imagePaths,
      pdfPath: clearPdfPath ? null : (pdfPath ?? this.pdfPath),
      aiResult: clearAiResult ? null : (aiResult ?? this.aiResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
