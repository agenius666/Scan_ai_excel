import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../models/excel_rule.dart';
import '../models/scan_task.dart';
import '../models/workbook_session.dart';
import 'save_path_service.dart';
import 'storage_service.dart';

class ExcelImportResult {
  ExcelImportResult({required this.session, required this.tasks});

  final WorkbookSession session;
  final List<ScanTask> tasks;
}

class ExcelValidationResult {
  const ExcelValidationResult({required this.sheetExists, required this.headerRowValid, required this.missingColumns});

  final bool sheetExists;
  final bool headerRowValid;
  final List<String> missingColumns;

  bool get ok => sheetExists && headerRowValid && missingColumns.isEmpty;

  String? buildMessage(ExcelRule rule) {
    if (!sheetExists) {
      return '未找到 Sheet「${rule.sheetName}」。请确认 Sheet 名是否正确。';
    }
    if (!headerRowValid) {
      return '表头行超出范围。请确认“表头所在行”是否正确。';
    }
    if (missingColumns.isNotEmpty) {
      return '以下列名不存在：${missingColumns.join('、')}。请确认任务名称列、PDF 命名列、核验字段、结果列名与表头行配置。';
    }
    return null;
  }
}

class ExcelService {
  ExcelService({StorageService? storageService, SavePathService? savePathService})
      : _storageService = storageService ?? StorageService(),
        _savePathService = savePathService ?? SavePathService();

  final StorageService _storageService;
  final SavePathService _savePathService;

  Future<ExcelImportResult?> pickAndParse(ExcelRule rule) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx'], withData: true);
    if (picked == null || picked.files.isEmpty) return null;
    final selected = picked.files.single;
    final Uint8List bytes = selected.bytes ?? await File(selected.path!).readAsBytes();
    return parseBytes(rule: rule, bytes: bytes, fileName: selected.name);
  }

  Future<ExcelImportResult> parseFromPath({required ExcelRule rule, required String path}) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return parseBytes(rule: rule, bytes: bytes, fileName: file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'shared.xlsx');
  }

  ExcelImportResult parseBytes({required ExcelRule rule, required Uint8List bytes, required String fileName}) {
    late Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw Exception('当前 Excel 文件包含某些特殊格式，当前解析失败。\n建议先用 Excel/WPS 打开后“另存为 .xlsx”再导入。\n原始错误：$e');
    }

    final validation = validateWorkbook(excel: excel, rule: rule);
    final validationMessage = validation.buildMessage(rule);
    if (validationMessage != null) {
      throw Exception(validationMessage);
    }

    final sheet = excel.tables[rule.sheetName]!;
    final headers = _extractHeaders(sheet, rule.headerRowIndex);

    final tasks = <ScanTask>[];
    for (var i = rule.headerRowIndex + 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowMap = _rowToMap(headers, row);
      if (_isEmptyRow(rowMap)) continue;
      final taskName = (rowMap[rule.taskNameColumn] ?? '').trim();
      final taskDisplayName = taskName.isEmpty ? '第${i + 1}行' : taskName;
      final pdfNameSeed = (rowMap[rule.pdfNameColumn] ?? taskDisplayName).trim();
      tasks.add(ScanTask(rowIndex: i, taskName: taskDisplayName, pdfFileNameStem: _sanitizeFileName(pdfNameSeed.isEmpty ? taskDisplayName : pdfNameSeed), rowData: rowMap));
    }

    final session = WorkbookSession(excel: excel, sheetName: rule.sheetName, sourceFileName: fileName, headerRowIndex: rule.headerRowIndex, headers: headers);
    return ExcelImportResult(session: session, tasks: tasks);
  }

  ExcelValidationResult validateWorkbook({required Excel excel, required ExcelRule rule}) {
    final sheet = excel.tables[rule.sheetName];
    if (sheet == null) {
      return const ExcelValidationResult(sheetExists: false, headerRowValid: false, missingColumns: []);
    }
    if (sheet.rows.length <= rule.headerRowIndex || rule.headerRowIndex < 0) {
      return const ExcelValidationResult(sheetExists: true, headerRowValid: false, missingColumns: []);
    }

    final headers = _extractHeaders(sheet, rule.headerRowIndex);
    final requiredColumns = <String>{
      if (rule.taskNameColumn.trim().isNotEmpty) rule.taskNameColumn.trim(),
      if (rule.pdfNameColumn.trim().isNotEmpty) rule.pdfNameColumn.trim(),
      ...rule.checkColumns.map((e) => e.trim()).where((e) => e.isNotEmpty),
    };
    final missingColumns = requiredColumns.where((column) => !headers.contains(column)).toList();
    return ExcelValidationResult(sheetExists: true, headerRowValid: true, missingColumns: missingColumns);
  }

  Future<void> writeResult({required WorkbookSession session, required int rowIndex, required String resultColumnName, required String value}) async {
    final sheet = session.excel.tables[session.sheetName];
    if (sheet == null) throw Exception('当前会话中的 Sheet 已丢失。');

    var headerNames = _extractHeaders(sheet, session.headerRowIndex);
    var resultColIndex = headerNames.indexOf(resultColumnName);
    if (resultColIndex == -1) {
      resultColIndex = headerNames.length;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: resultColIndex, rowIndex: session.headerRowIndex)).value = resultColumnName;
      session.headers.add(resultColumnName);
      headerNames = _extractHeaders(sheet, session.headerRowIndex);
    }
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: resultColIndex, rowIndex: rowIndex)).value = value;
  }

  Future<TreeWriteResult> exportWorkbook(WorkbookSession session, {String? saveBasePath, String? saveTreeUri}) async {
    final bytes = session.excel.save();
    if (bytes == null) throw Exception('Excel 导出失败。');
    final baseName = session.sourceFileName.toLowerCase().endsWith('.xlsx') ? session.sourceFileName.substring(0, session.sourceFileName.length - 5) : session.sourceFileName;
    final fileName = '${_sanitizeFileName(baseName)}_已核验_${_timestamp()}.xlsx';

    if (saveTreeUri != null && saveTreeUri.isNotEmpty) {
      final result = await _savePathService.writeBytesToTree(
        treeUri: saveTreeUri,
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      return result;
    }

    final dir = await _storageService.getExportDirectory(configuredBasePath: saveBasePath);
    final outputPath = '${dir.path}/$fileName';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(bytes, flush: true);
    return TreeWriteResult(uri: outputFile.path, displayPath: outputFile.path);
  }

  List<String> _extractHeaders(Sheet sheet, int headerRowIndex) => sheet.rows[headerRowIndex].map((cell) => _cellToString(cell?.value).trim()).toList();

  Map<String, String> _rowToMap(List<String> headers, List<dynamic> row) {
    final map = <String, String>{};
    for (var colIndex = 0; colIndex < headers.length; colIndex++) {
      final header = headers[colIndex].trim();
      if (header.isEmpty) continue;
      final value = colIndex < row.length ? _cellToString(row[colIndex]?.value) : '';
      map[header] = value;
    }
    return map;
  }

  bool _isEmptyRow(Map<String, String> rowMap) => rowMap.values.every((value) => value.trim().isEmpty);
  String _cellToString(dynamic value) => value == null ? '' : value.toString();
  String _sanitizeFileName(String input) => input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  String _timestamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.month)}${two(now.day)}${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
