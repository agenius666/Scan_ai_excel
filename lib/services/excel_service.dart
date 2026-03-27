import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../models/excel_rule.dart';
import '../models/scan_task.dart';
import '../models/workbook_session.dart';
import 'storage_service.dart';

class ExcelImportResult {
  ExcelImportResult({
    required this.session,
    required this.tasks,
  });

  final WorkbookSession session;
  final List<ScanTask> tasks;
}

class ExcelService {
  ExcelService({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  final StorageService _storageService;

  Future<ExcelImportResult?> pickAndParse(ExcelRule rule) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) {
      return null;
    }

    final selected = picked.files.single;
    final Uint8List bytes = selected.bytes ?? await File(selected.path!).readAsBytes();

    late Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw Exception('当前 Excel 文件包含某些特殊格式，当前解析失败。\n建议先用 Excel/WPS 打开后“另存为 .xlsx”再导入。\n原始错误：$e');
    }

    final sheet = excel.tables[rule.sheetName];
    if (sheet == null) throw Exception('未找到 Sheet：${rule.sheetName}');
    if (sheet.rows.length <= rule.headerRowIndex) throw Exception('表头行超出范围，请检查表头行号配置。');

    final headers = _extractHeaders(sheet, rule.headerRowIndex);
    final missingColumns = <String>[];
    final requiredColumns = {rule.taskNameColumn, rule.pdfNameColumn, ...rule.checkColumns};
    for (final column in requiredColumns) {
      if (!headers.contains(column)) {
        missingColumns.add(column);
      }
    }
    if (missingColumns.isNotEmpty) {
      throw Exception('以下列在 Excel 中不存在：${missingColumns.join('、')}');
    }

    final tasks = <ScanTask>[];
    for (var i = rule.headerRowIndex + 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowMap = _rowToMap(headers, row);
      if (_isEmptyRow(rowMap)) continue;
      final taskName = (rowMap[rule.taskNameColumn] ?? '').trim();
      final taskDisplayName = taskName.isEmpty ? '第${i + 1}行' : taskName;
      final pdfNameSeed = (rowMap[rule.pdfNameColumn] ?? taskDisplayName).trim();
      tasks.add(
        ScanTask(
          rowIndex: i,
          taskName: taskDisplayName,
          pdfFileNameStem: _sanitizeFileName(pdfNameSeed.isEmpty ? taskDisplayName : pdfNameSeed),
          rowData: rowMap,
        ),
      );
    }

    final session = WorkbookSession(
      excel: excel,
      sheetName: rule.sheetName,
      sourceFileName: selected.name,
      headerRowIndex: rule.headerRowIndex,
      headers: headers,
    );

    return ExcelImportResult(session: session, tasks: tasks);
  }

  Future<void> writeResult({
    required WorkbookSession session,
    required int rowIndex,
    required String resultColumnName,
    required String value,
  }) async {
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

  Future<String> exportWorkbook(WorkbookSession session) async {
    final bytes = session.excel.save();
    if (bytes == null) throw Exception('Excel 导出失败。');

    final dir = await _storageService.getDownloadDirectory();
    final baseName = session.sourceFileName.toLowerCase().endsWith('.xlsx')
        ? session.sourceFileName.substring(0, session.sourceFileName.length - 5)
        : session.sourceFileName;

    final outputPath = '${dir.path}/${_sanitizeFileName(baseName)}_已核验_${_timestamp()}.xlsx';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(bytes, flush: true);
    return outputFile.path;
  }

  List<String> _extractHeaders(Sheet sheet, int headerRowIndex) {
    final headerRow = sheet.rows[headerRowIndex];
    return headerRow.map((cell) => _cellToString(cell?.value).trim()).toList();
  }

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

  bool _isEmptyRow(Map<String, String> rowMap) {
    return rowMap.values.every((value) => value.trim().isEmpty);
  }

  String _cellToString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  String _sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
