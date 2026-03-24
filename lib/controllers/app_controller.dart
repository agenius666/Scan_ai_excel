import 'package:flutter/foundation.dart';

import '../models/ai_check_result.dart';
import '../models/ai_config.dart';
import '../models/excel_rule.dart';
import '../models/scan_task.dart';
import '../models/workbook_session.dart';
import '../services/ai_service.dart';
import '../services/excel_service.dart';
import '../services/pdf_service.dart';
import '../services/scanner_service.dart';
import '../services/settings_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required SettingsService settingsService,
    required ExcelService excelService,
    required ScannerService scannerService,
    required PdfService pdfService,
    required AiService aiService,
  })  : _settingsService = settingsService,
        _excelService = excelService,
        _scannerService = scannerService,
        _pdfService = pdfService,
        _aiService = aiService;

  final SettingsService _settingsService;
  final ExcelService _excelService;
  final ScannerService _scannerService;
  final PdfService _pdfService;
  final AiService _aiService;

  AiConfig _aiConfig = AiConfig.defaults;
  ExcelRule _excelRule = ExcelRule.defaults;
  WorkbookSession? _session;
  List<ScanTask> _tasks = const [];
  bool _busy = false;
  String? _currentMessage;
  String? _lastExportPath;

  AiConfig get aiConfig => _aiConfig;
  ExcelRule get excelRule => _excelRule;
  WorkbookSession? get session => _session;
  List<ScanTask> get tasks => _tasks;
  bool get busy => _busy;
  String? get currentMessage => _currentMessage;
  String? get lastExportPath => _lastExportPath;
  String? get currentExcelName => _session?.sourceFileName;

  int get totalCount => _tasks.length;
  int get pendingCount =>
      _tasks.where((task) => task.status == TaskStatus.pending).length;
  int get scannedCount =>
      _tasks.where((task) => task.status == TaskStatus.scanned).length;
  int get doneCount =>
      _tasks.where((task) => task.status == TaskStatus.done).length;
  int get failedCount =>
      _tasks.where((task) => task.status == TaskStatus.failed).length;

  Future<void> initialize() async {
    _aiConfig = await _settingsService.loadAiConfig();
    _excelRule = await _settingsService.loadExcelRule();
    notifyListeners();
  }

  Future<void> saveSettings({
    required AiConfig aiConfig,
    required ExcelRule excelRule,
  }) async {
    _aiConfig = aiConfig;
    _excelRule = excelRule;
    await _settingsService.saveAiConfig(aiConfig);
    await _settingsService.saveExcelRule(excelRule);
    notifyListeners();
  }

  Future<void> importExcel() async {
    _setBusy(true, '正在导入 Excel...');
    try {
      final result = await _excelService.pickAndParse(_excelRule);
      if (result == null) {
        return;
      }
      _session = result.session;
      _tasks = result.tasks;
      _lastExportPath = null;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<String> exportExcel() async {
    final activeSession = _session;
    if (activeSession == null) {
      throw Exception('请先导入 Excel。');
    }
    _setBusy(true, '正在导出 Excel...');
    try {
      final path = await _excelService.exportWorkbook(activeSession);
      _lastExportPath = path;
      notifyListeners();
      return path;
    } finally {
      _setBusy(false);
    }
  }

  ScanTask? taskByRowIndex(int rowIndex) {
    try {
      return _tasks.firstWhere((task) => task.rowIndex == rowIndex);
    } catch (_) {
      return null;
    }
  }

  Future<ScanTask?> scanTask(ScanTask task) async {
    _replaceTask(
      task.copyWith(
        status: TaskStatus.scanning,
        imagePaths: const [],
        clearPdfPath: true,
        clearAiResult: true,
        clearError: true,
      ),
    );

    try {
      final imagePaths = await _scannerService.scanToPermanentImages(
        fileNameStem: task.pdfFileNameStem,
      );
      if (imagePaths.isEmpty) {
        final cancelled = task.copyWith(
          status: TaskStatus.pending,
          clearError: true,
          imagePaths: const [],
          clearPdfPath: true,
          clearAiResult: true,
        );
        _replaceTask(cancelled);
        return null;
      }

      final updated = task.copyWith(
        status: TaskStatus.scanned,
        imagePaths: imagePaths,
        clearPdfPath: true,
        clearAiResult: true,
        clearError: true,
      );
      _replaceTask(updated);
      return updated;
    } catch (e) {
      final failed = task.copyWith(
        status: TaskStatus.failed,
        errorMessage: e.toString(),
        clearPdfPath: true,
        clearAiResult: true,
      );
      _replaceTask(failed);
      rethrow;
    }
  }

  Future<ScanTask> processScannedTask(ScanTask task) async {
    final activeSession = _session;
    if (activeSession == null) {
      throw Exception('请先导入 Excel。');
    }
    if (task.imagePaths.isEmpty) {
      throw Exception('当前任务没有扫描图片，请先扫描。');
    }

    final checkingTask = task.copyWith(
      status: TaskStatus.checking,
      clearError: true,
    );
    _replaceTask(checkingTask);

    try {
      final pdfPath = await _pdfService.generatePdf(
        imagePaths: task.imagePaths,
        fileNameStem: task.pdfFileNameStem,
      );

      final aiResult = await _aiService.checkDocument(
        config: _aiConfig,
        rule: _excelRule,
        rowData: task.rowData,
        imagePaths: task.imagePaths,
      );

      await _excelService.writeResult(
        session: activeSession,
        rowIndex: task.rowIndex,
        resultColumnName: _excelRule.resultColumnName,
        value: aiResult.toExcelCellText(),
      );

      final doneTask = task.copyWith(
        status: TaskStatus.done,
        pdfPath: pdfPath,
        aiResult: aiResult,
        clearError: true,
      );
      _replaceTask(doneTask);
      return doneTask;
    } catch (e) {
      final failedTask = task.copyWith(
        status: TaskStatus.failed,
        errorMessage: e.toString(),
      );
      _replaceTask(failedTask);
      rethrow;
    }
  }

  Future<List<int>> loadPdfBytes(String pdfPath) {
    return _pdfService.loadPdfBytes(pdfPath);
  }

  Future<void> writeManualResult({
    required ScanTask task,
    required AiCheckResult result,
  }) async {
    final activeSession = _session;
    if (activeSession == null) {
      throw Exception('请先导入 Excel。');
    }
    await _excelService.writeResult(
      session: activeSession,
      rowIndex: task.rowIndex,
      resultColumnName: _excelRule.resultColumnName,
      value: result.toExcelCellText(),
    );
    final updated = task.copyWith(
      status: TaskStatus.done,
      aiResult: result,
      clearError: true,
    );
    _replaceTask(updated);
  }

  void _replaceTask(ScanTask updated) {
    _tasks = _tasks
        .map((task) => task.rowIndex == updated.rowIndex ? updated : task)
        .toList(growable: false);
    notifyListeners();
  }

  void _setBusy(bool value, [String? message]) {
    _busy = value;
    _currentMessage = value ? message : null;
    notifyListeners();
  }
}
