import 'package:flutter/material.dart';
import '../services/file_service.dart';

class FileListItem extends StatelessWidget {
  final ExcelRow row;
  final VoidCallback onTap;

  const FileListItem({Key? key, required this.row, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(row.fileName),
        subtitle: Text(row.question),
        trailing: Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }
}
