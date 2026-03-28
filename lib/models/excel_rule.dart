import '../utils/rule_utils.dart';

class ExcelRule {
  const ExcelRule({
    required this.sheetName,
    required this.headerRowIndex,
    required this.taskNameColumn,
    required this.pdfNameColumn,
    required this.checkColumns,
    required this.resultColumnName,
    required this.promptTemplate,
  });

  final String sheetName;
  final int headerRowIndex;
  final String taskNameColumn;
  final String pdfNameColumn;
  final List<String> checkColumns;
  final String resultColumnName;
  final String promptTemplate;

  static const ExcelRule defaults = ExcelRule(
    sheetName: 'Sheet1',
    headerRowIndex: 0,
    taskNameColumn: '单号',
    pdfNameColumn: '单号',
    checkColumns: ['客户名称', '金额', '日期'],
    resultColumnName: '核验结果',
    promptTemplate: '''
你是文档核验助手。请根据扫描图片核验 Excel 字段与文档内容是否一致。

待核验字段：
{{fields_block}}

要求：
1. 只返回 JSON 对象，不要返回 Markdown 代码块。
2. JSON 结构固定为：
{
  "final_pass": true,
  "summary": "一句中文总结",
  "fields": {
    "字段名": {
      "expected": "Excel中的值",
      "found": "文档中识别到的值",
      "pass": true,
      "note": "补充说明"
    }
  }
}
3. 如果文档中无法确认某个字段，found 置空字符串，pass 为 false。
''',
  );

  String get checkColumnsCsv => checkColumns.join(',');

  ExcelRule copyWith({
    String? sheetName,
    int? headerRowIndex,
    String? taskNameColumn,
    String? pdfNameColumn,
    List<String>? checkColumns,
    String? resultColumnName,
    String? promptTemplate,
  }) {
    return ExcelRule(
      sheetName: sheetName ?? this.sheetName,
      headerRowIndex: headerRowIndex ?? this.headerRowIndex,
      taskNameColumn: taskNameColumn ?? this.taskNameColumn,
      pdfNameColumn: pdfNameColumn ?? this.pdfNameColumn,
      checkColumns: checkColumns ?? this.checkColumns,
      resultColumnName: resultColumnName ?? this.resultColumnName,
      promptTemplate: promptTemplate ?? this.promptTemplate,
    );
  }

  Map<String, String> toMap() {
    return {
      'sheetName': sheetName,
      'headerRowIndex': headerRowIndex.toString(),
      'taskNameColumn': taskNameColumn,
      'pdfNameColumn': pdfNameColumn,
      'checkColumns': checkColumnsCsv,
      'resultColumnName': resultColumnName,
      'promptTemplate': promptTemplate,
    };
  }

  factory ExcelRule.fromMap(Map<String, String> map) {
    final checkColumnsRaw = map['checkColumns'] ?? defaults.checkColumnsCsv;
    final checkColumns = parseCheckColumns(checkColumnsRaw);

    return ExcelRule(
      sheetName: map['sheetName']?.trim().isNotEmpty == true
          ? map['sheetName']!.trim()
          : defaults.sheetName,
      headerRowIndex:
          int.tryParse(map['headerRowIndex'] ?? '') ?? defaults.headerRowIndex,
      taskNameColumn: map['taskNameColumn']?.trim().isNotEmpty == true
          ? map['taskNameColumn']!.trim()
          : defaults.taskNameColumn,
      pdfNameColumn: map['pdfNameColumn']?.trim().isNotEmpty == true
          ? map['pdfNameColumn']!.trim()
          : defaults.pdfNameColumn,
      checkColumns: checkColumns.isEmpty ? defaults.checkColumns : checkColumns,
      resultColumnName: map['resultColumnName']?.trim().isNotEmpty == true
          ? map['resultColumnName']!.trim()
          : defaults.resultColumnName,
      promptTemplate: map['promptTemplate']?.trim().isNotEmpty == true
          ? map['promptTemplate']!
          : defaults.promptTemplate,
    );
  }
}
