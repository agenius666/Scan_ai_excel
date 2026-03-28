import 'dart:async';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import 'controllers/app_controller.dart';
import 'models/excel_rule.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'services/ai_service.dart';
import 'services/excel_service.dart';
import 'services/history_service.dart';
import 'services/pdf_service.dart';
import 'services/scanner_service.dart';
import 'services/settings_service.dart';
import 'services/share_import_service.dart';
import 'services/task_queue_service.dart';
import 'utils/rule_utils.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController(
    settingsService: SettingsService(),
    excelService: ExcelService(),
    scannerService: ScannerService(),
    pdfService: PdfService(),
    aiService: AiService(),
    historyService: HistoryService(),
    taskQueueService: TaskQueueService(),
  );

  runApp(ScanAiExcelApp(controller: controller));
}

class ScanAiExcelApp extends StatefulWidget {
  const ScanAiExcelApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<ScanAiExcelApp> createState() => _ScanAiExcelAppState();
}

class _ScanAiExcelAppState extends State<ScanAiExcelApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final Future<void> _initializeFuture;
  int _currentIndex = 0;
  final ShareImportService _shareImportService = ShareImportService();
  String? _pendingSharedPath;
  bool _shareDialogShown = false;
  bool _shareDialogActive = false;
  StreamSubscription<String>? _shareSub;

  @override
  void initState() {
    super.initState();
    _initializeFuture = _initAll();
    _shareSub = _shareImportService.watchIncomingSharedFiles().listen(_scheduleShareDialog);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  Future<void> _initAll() async {
    await widget.controller.initialize();
    _pendingSharedPath = await _shareImportService.getInitialSharedFile();
  }

  void _scheduleShareDialog(String path) {
    if (!mounted || path.isEmpty) return;
    _pendingSharedPath = path;
    if (_shareDialogActive) return;
    _shareDialogShown = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shareDialogShown || _shareDialogActive) return;
      _shareDialogShown = true;
      _showShareImportDialog(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'ScanExcel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_shareDialogShown && _pendingSharedPath != null && _pendingSharedPath!.isNotEmpty) {
              _scheduleShareDialog(_pendingSharedPath!);
            }
          });

          return Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: [
                HomePage(controller: widget.controller),
                SettingsPage(controller: widget.controller),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showShareImportDialog(String path) async {
    var confirmedImport = false;
    final dialogHostContext = _navigatorKey.currentContext;
    if (dialogHostContext == null) {
      _shareDialogShown = false;
      return;
    }

    _shareDialogActive = true;
    final currentRule = widget.controller.excelRule;
    final sheetController = TextEditingController(text: currentRule.sheetName);
    final headerRowController = TextEditingController(text: (currentRule.headerRowIndex + 1).toString());
    final taskNameController = TextEditingController(text: currentRule.taskNameColumn);
    final pdfNameController = TextEditingController(text: currentRule.pdfNameColumn);
    final checkColumnsController = TextEditingController(text: currentRule.checkColumnsCsv);
    final resultColumnController = TextEditingController(text: currentRule.resultColumnName);
    final saveAsDefault = ValueNotifier<bool>(false);

    try {
      await showDialog(
        context: dialogHostContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('共享 Excel 导入确认'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: sheetController, decoration: const InputDecoration(labelText: 'Sheet 名')),
                  TextField(controller: headerRowController, decoration: const InputDecoration(labelText: '表头所在行（从 1 开始）'), keyboardType: TextInputType.number),
                  TextField(controller: taskNameController, decoration: const InputDecoration(labelText: '任务名称列')),
                  TextField(controller: pdfNameController, decoration: const InputDecoration(labelText: 'PDF 命名列')),
                  TextField(controller: checkColumnsController, decoration: const InputDecoration(labelText: '核验字段（逗号分隔）')),
                  TextField(controller: resultColumnController, decoration: const InputDecoration(labelText: '结果列名')),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: saveAsDefault,
                    builder: (_, value, __) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: value,
                      onChanged: (v) => saveAsDefault.value = v ?? false,
                      title: const Text('同时保存为默认规则'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
              FilledButton(
                onPressed: () async {
                  final updatedRule = ExcelRule(
                    sheetName: sheetController.text.trim(),
                    headerRowIndex: (int.tryParse(headerRowController.text.trim()) ?? 1) - 1,
                    taskNameColumn: taskNameController.text.trim(),
                    pdfNameColumn: pdfNameController.text.trim(),
                    checkColumns: parseCheckColumns(checkColumnsController.text),
                    resultColumnName: resultColumnController.text.trim(),
                    promptTemplate: currentRule.promptTemplate,
                  );

                  final precheckError = await _precheckSharedExcel(path, updatedRule);
                  if (precheckError != null) {
                    if (!dialogContext.mounted) return;
                    await showDialog(
                      context: dialogContext,
                      useRootNavigator: true,
                      builder: (errorContext) => AlertDialog(
                        title: const Text('导入前检查失败'),
                        content: Text(precheckError),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.of(errorContext).pop(),
                            child: const Text('我知道了'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  try {
                    await widget.controller.importSharedExcel(path, ruleOverride: updatedRule);
                    confirmedImport = true;
                    if (saveAsDefault.value) {
                      await widget.controller.saveSettings(
                        aiConfig: widget.controller.aiConfig,
                        excelRule: updatedRule,
                        saveBasePath: widget.controller.saveBasePath,
                        saveTreeUri: widget.controller.saveTreeUri,
                      );
                    }
                    _pendingSharedPath = null;
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  } catch (e) {
                    if (!dialogContext.mounted) return;
                    await showDialog(
                      context: dialogContext,
                      useRootNavigator: true,
                      builder: (errorContext) => AlertDialog(
                        title: const Text('导入失败'),
                        content: Text('导入失败：$e\n\n请重点检查 Sheet 名、表头行、任务名称列、PDF 命名列与核验字段是否和当前 xlsx 一致。'),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.of(errorContext).pop(),
                            child: const Text('我知道了'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: const Text('确认导入'),
              ),
            ],
          );
        },
      );
    } finally {
      _shareDialogActive = false;
      _shareDialogShown = false;
      if (!confirmedImport && _pendingSharedPath == path) {
        _pendingSharedPath = null;
      }
    }
  }

  Future<String?> _precheckSharedExcel(String path, ExcelRule rule) async {
    try {
      final bytes = await File(path).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[rule.sheetName];
      if (sheet == null) {
        return '导入前检查失败：未找到 Sheet「${rule.sheetName}」。请确认 Sheet 名是否正确。';
      }
      if (sheet.rows.length <= rule.headerRowIndex) {
        return '导入前检查失败：表头行超出范围。请确认“表头所在行”是否正确。';
      }
      final validation = ExcelService().validateWorkbook(excel: excel, rule: rule);
      final message = validation.buildMessage(rule);
      if (message != null) {
        return '导入前检查失败：$message';
      }
      return null;
    } catch (e) {
      return '导入前检查失败：无法解析该 xlsx 文件。原始错误：$e';
    }
  }
}
