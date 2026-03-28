import 'package:flutter/material.dart';

import '../models/ai_check_result.dart';
import '../models/ai_config.dart';
import '../models/excel_rule.dart';
import '../models/history_record.dart';
import '../models/scan_task.dart';
import '../models/workbook_session.dart';
import '../services/ai_service.dart';
import '../services/excel_service.dart';
import '../services/history_service.dart';
import '../services/pdf_service.dart';
import '../services/scanner_service.dart';
import '../services/settings_service.dart';
import '../services/task_queue_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required SettingsService settingsService,
    required ExcelService excelService,
    required ScannerService scannerService,
    required PdfService pdfService,
    required AiService aiService,
    required HistoryService historyService,
    required TaskQueueService taskQueueService,
  })  : _settingsService = settingsService,
        _excelService = excelService,
        _scannerService = scannerService,
        _pdfService = pdfService,
        _aiService = aiService,
        _historyService = historyService,
        _taskQueueService = taskQueueService;

  final SettingsService _settingsService;
  final ExcelService _excelService;
  final ScannerService _scannerService;
  final PdfService _pdfService;
  final AiService _aiService;
  final HistoryService _historyService;
  final TaskQueueService _taskQueueService;

  AiConfig _aiConfig = AiConfig.defaults;
  ExcelRule _defaultExcelRule = ExcelRule.defaults;
  ExcelRule _activeExcelRule = ExcelRule.defaults;
  WorkbookSession? _session;
  List<ScanTask> _tasks = const [];
  bool _busy = false;
  String? _currentMessage;
  String? _lastExportPath;
  List<HistoryRecord> _history = const [];
  String _saveBasePath = '';
  String _saveTreeUri = '';

  AiConfig get aiConfig => _aiConfig;
  ExcelRule get excelRule => _activeExcelRule;
  ExcelRule get defaultExcelRule => _defaultExcelRule;
  WorkbookSession? get session => _session;
  List<ScanTask> get tasks => _tasks;
  bool get busy => _busy;
  String? get currentMessage => _currentMessage;
  String? get lastExportPath => _lastExportPath;
  String? get currentExcelName => _session?.sourceFileName;
  List<HistoryRecord> get history => _history;
  bool get queueRunning => _taskQueueService.running;
  String get saveBasePath => _saveBasePath;
  String get saveTreeUri => _saveTreeUri;

  int get totalCount => _tasks.length;
  int get pendingCount => _tasks.where((task) => task.status == TaskStatus.pending).length;
  int get scannedCount => _tasks.where((task) => task.status == TaskStatus.scanned).length;
  int get queuedCount => _tasks.where((task) => task.status == TaskStatus.queued).length;
  int get checkingCount => _tasks.where((task) => task.status == TaskStatus.checking).length;
  int get doneCount => _tasks.where((task) => task.status == TaskStatus.done).length;
  int get failedCount => _tasks.where((task) => task.status == TaskStatus.failed).length;

  Future<void> initialize() async {
    _aiConfig = await _settingsService.loadAiConfig();
    _defaultExcelRule = await _settingsService.loadExcelRule();
    _activeExcelRule = _defaultExcelRule;
    _saveBasePath = await _settingsService.loadSavePath() ?? '/storage/emulated/0/Download';
    _saveTreeUri = await _settingsService.loadSavePathTreeUri() ?? '';
    _history = await _historyService.load();
    notifyListeners();
  }

  ExcelValidationResult validateExcelRuleAgainstCurrentSession(ExcelRule rule) {
    final activeSession = _session;
    if (activeSession == null) {
      return const ExcelValidationResult(sheetExists: true, headerRowValid: true, missingColumns: []);
    }
    return _excelService.validateWorkbook(excel: activeSession.excel, rule: rule);
  }

  Future<void> saveSettings({
    required AiConfig aiConfig,
    required ExcelRule excelRule,
    required String saveBasePath,
    String? saveTreeUri,
  }) async {
    _aiConfig = aiConfig;
    _defaultExcelRule = excelRule;
    _activeExcelRule = excelRule;
    _saveBasePath = saveBasePath.trim().isEmpty ? '/storage/emulated/0/Download' : saveBasePath.trim();
    _saveTreeUri = saveTreeUri ?? _saveTreeUri;
    await _settingsService.saveAiConfig(aiConfig);
    await _settingsService.saveExcelRule(excelRule);
    await _settingsService.saveSavePath(_saveBasePath);
    await _settingsService.saveSavePathTreeUri(_saveTreeUri);
    notifyListeners();
  }

  Future<void> importExcel() async {
    _setBusy(true, '正在导入 Excel...');
    try {
      final result = await _excelService.pickAndParse(_activeExcelRule);
      if (result == null) return;
      _session = result.session;
      _tasks = result.tasks;
      _lastExportPath = null;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> importSharedExcel(String path, {ExcelRule? ruleOverride}) async {
    _setBusy(true, '正在导入共享 Excel...');
    try {
      final effectiveRule = ruleOverride ?? _activeExcelRule;
      final result = await _excelService.parseFromPath(rule: effectiveRule, path: path);
      _activeExcelRule = effectiveRule;
      _session = result.session;
      _tasks = result.tasks;
      _lastExportPath = null;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  void clearCurrentSession() {
    _session = null;
    _tasks = const [];
    _lastExportPath = null;
    _currentMessage = null;
    _activeExcelRule = _defaultExcelRule;
    notifyListeners();
  }

  Future<String> exportExcel() async {
    final activeSession = _session;
    if (activeSession == null) throw Exception('请先导入 Excel。');
    _setBusy(true, '正在导出 Excel...');
    try {
      final result = await _excelService.exportWorkbook(activeSession, saveBasePath: _saveBasePath, saveTreeUri: _saveTreeUri);
      _lastExportPath = result.displayPath;
      notifyListeners();
      return result.uri;
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

  ScanTask? nextTaskAfter(int rowIndex) {
    final sorted = [..._tasks]..sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
    for (final task in sorted) {
      if (task.rowIndex > rowIndex) return task;
    }
    return null;
  }

  Future<ScanTask?> scanTask(BuildContext context, ScanTask task) async {
    _replaceTask(task.copyWith(status: TaskStatus.scanning, imagePaths: const [], clearPdfPath: true, clearAiResult: true, clearError: true));
    try {
      final imagePaths = await _scannerService.scanToPermanentImages(context: context, fileNameStem: task.pdfFileNameStem);
      if (imagePaths.isEmpty) {
        final cancelled = task.copyWith(status: TaskStatus.pending, clearError: true, imagePaths: const [], clearPdfPath: true, clearAiResult: true);
        _replaceTask(cancelled);
        return null;
      }
      final updated = task.copyWith(status: TaskStatus.scanned, createdAt: DateTime.now(), imagePaths: imagePaths, clearPdfPath: true, clearAiResult: true, clearError: true);
      _replaceTask(updated);
      return updated;
    } catch (e) {
      final failed = task.copyWith(status: TaskStatus.failed, errorMessage: e.toString(), clearPdfPath: true, clearAiResult: true);
      _replaceTask(failed);
      rethrow;
    }
  }

  Future<void> enqueueTaskForChecking(ScanTask task) async {
    final activeSession = _session;
    if (activeSession == null) throw Exception('请先导入 Excel。');
    if (task.imagePaths.isEmpty) throw Exception('当前任务没有扫描图片，请先扫描。');

    final queuedTask = task.copyWith(status: TaskStatus.queued, clearError: true, clearAiResult: true);
    _replaceTask(queuedTask);
    _currentMessage = '核验队列：$queuedCount 排队，$checkingCount 进行中，$doneCount 已完成';
    notifyListeners();

    if (!_taskQueueService.running) {
      Future.microtask(() => _taskQueueService.processPending(this));
    }
  }

  Future<ScanTask> processQueuedTask(ScanTask task) async {
    final activeSession = _session;
    if (activeSession == null) throw Exception('请先导入 Excel。');
    if (task.imagePaths.isEmpty) throw Exception('当前任务没有扫描图片，请先扫描。');

    final checkingTask = task.copyWith(status: TaskStatus.checking, clearError: true);
    _replaceTask(checkingTask);
    _currentMessage = '正在核验：${task.taskName}';
    notifyListeners();

    try {
      final aiResult = await _aiService.checkDocument(config: _aiConfig, rule: _activeExcelRule, rowData: task.rowData, imagePaths: task.imagePaths);
      await _excelService.writeResult(session: activeSession, rowIndex: task.rowIndex, resultColumnName: _activeExcelRule.resultColumnName, value: aiResult.toExcelCellText());

      final latestTask = taskByRowIndex(task.rowIndex) ?? task;
      final doneTask = latestTask.copyWith(status: TaskStatus.done, aiResult: aiResult, clearError: true);
      _replaceTask(doneTask);
      final record = HistoryRecord(
        id: '${task.rowIndex}-${DateTime.now().millisecondsSinceEpoch}',
        taskName: task.taskName,
        pdfPath: doneTask.pdfPath ?? '',
        excelPath: activeSession.sourceFileName,
        createdAt: DateTime.now().toIso8601String(),
        status: doneTask.status.label,
        summary: aiResult.summary,
      );
      await _historyService.append(record);
      _history = await _historyService.load();
      _currentMessage = '核验队列：$queuedCount 排队，$checkingCount 进行中，$doneCount 已完成';
      notifyListeners();
      return doneTask;
    } catch (e) {
      final failedTask = task.copyWith(status: TaskStatus.failed, errorMessage: e.toString());
      _replaceTask(failedTask);
      _currentMessage = '任务失败：${task.taskName}';
      notifyListeners();
      rethrow;
    }
  }

  Future<String> generatePdfForTask(ScanTask task) async {
    if (task.imagePaths.isEmpty) throw Exception('当前任务没有扫描图片，请先扫描。');
    final result = await _pdfService.generatePdf(imagePaths: task.imagePaths, fileNameStem: task.pdfFileNameStem, saveBasePath: _saveBasePath, saveTreeUri: _saveTreeUri);
    final latestTask = taskByRowIndex(task.rowIndex) ?? task;
    _replaceTask(latestTask.copyWith(pdfPath: result.uri, pdfDisplayPath: result.displayPath, clearError: true));
    return result.displayPath;
  }

  Future<List<int>> loadPdfBytes(String pdfPath) => _pdfService.loadPdfBytes(pdfPath);
  Future<String> savePdfToDownloads(String pdfPath) => _pdfService.saveCopyToDownloads(pdfPath, saveBasePath: _saveBasePath);
  Future<void> processQueue() async {
    await _taskQueueService.processPending(this);
    notifyListeners();
  }

  Future<void> writeManualResult({required ScanTask task, required AiCheckResult result}) async {
    final activeSession = _session;
    if (activeSession == null) throw Exception('请先导入 Excel。');
    await _excelService.writeResult(session: activeSession, rowIndex: task.rowIndex, resultColumnName: _activeExcelRule.resultColumnName, value: result.toExcelCellText());
    final updated = task.copyWith(status: TaskStatus.done, aiResult: result, clearError: true);
    _replaceTask(updated);
  }

  void notifyQueueStateChanged() {
    _currentMessage = '核验队列：$queuedCount 排队，$checkingCount 进行中，$doneCount 已完成';
    notifyListeners();
  }

  void _replaceTask(ScanTask updated) {
    _tasks = _tasks.map((task) => task.rowIndex == updated.rowIndex ? updated : task).toList(growable: false);
    notifyListeners();
  }

  void _setBusy(bool value, [String? message]) {
    _busy = value;
    _currentMessage = value ? message : null;
    notifyListeners();
  }
}
