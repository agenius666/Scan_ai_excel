import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:image_cropper/image_cropper.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

import '../services/file_service.dart';
import '../services/camera_service.dart';
import '../services/pdf_service.dart';
import '../widgets/file_list_item.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ExcelRow> _excelRows = [];
  String? _excelFilePath;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('扫描全能王+AI'),
        actions: [
          IconButton(icon: Icon(Icons.upload), onPressed: _pickExcelFile),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _excelFilePath != null
          ? ListView.builder(
              itemCount: _excelRows.length,
              itemBuilder: (context, index) {
                return FileListItem(
                  row: _excelRows[index],
                  onTap: () => _startScanning(_excelRows[index]),
                );
              },
            )
          : Center(child: Text('请上传XLSX文件')),
    );
  }

  Future<void> _pickExcelFile() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        _excelFilePath = result.files.single.path;
        final rows = await FileService.parseExcel(_excelFilePath!);
        setState(() {
          _excelRows = rows;
        });
      }
    } catch (e) {
      print('Error picking file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startScanning(ExcelRow row) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          cameras: widget.cameras,
          excelRow: row,
          excelFilePath: _excelFilePath!,
        ),
      ),
    );
  }
}
