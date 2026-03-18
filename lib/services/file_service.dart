import 'package:excel/excel.dart';
import 'dart:io';
import 'dart:convert';

class ExcelRow {
  final int id;
  final String fileName;
  final String question;

  ExcelRow({required this.id, required this.fileName, required this.question});
}

class FileService {
  static Future<List<ExcelRow>> parseExcel(String filePath) async {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    final sheet = excel['Sheet1'];
    final rows = <ExcelRow>[];

    // 假设第一行是标题，从第二行开始是数据
    for (int i = 1; i < sheet!.maxRows; i++) {
      final cell = sheet.cell(CellIndex.indexByString('A${i + 1}'));
      final fileName = cell.value.toString();

      final questionCell = sheet.cell(CellIndex.indexByString('B${i + 1}'));
      final question = questionCell.value.toString();

      rows.add(ExcelRow(id: i, fileName: fileName, question: question));
    }

    return rows;
  }

  static Future<void> updateExcelWithAIResponse({
    required String excelFilePath,
    required int rowId,
    required String aiResponse,
  }) async {
    final file = File(excelFilePath);
    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    final sheet = excel['Sheet1'];

    // 假设AI响应存储在最后一列（Z列）
    final cell = sheet!.cell(CellIndex.indexByString('Z${rowId + 1}'));
    cell.value = TextCellValue(aiResponse);

    // 保存修改后的Excel文件
    final updatedBytes = excel.save()!;
    await file.writeAsBytes(updatedBytes);
  }
}
