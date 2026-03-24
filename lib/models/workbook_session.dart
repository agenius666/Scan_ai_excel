import 'package:excel/excel.dart';

class WorkbookSession {
  WorkbookSession({
    required this.excel,
    required this.sheetName,
    required this.sourceFileName,
    required this.headerRowIndex,
    required this.headers,
  });

  final Excel excel;
  final String sheetName;
  final String sourceFileName;
  final int headerRowIndex;
  final List<String> headers;
}
