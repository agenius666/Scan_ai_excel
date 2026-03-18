import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

import '../services/pdf_service.dart';
import '../services/ai_service.dart';
import '../utils/constants.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ExcelRow excelRow;
  final String excelFilePath;

  const CameraScreen({
    Key? key,
    required this.cameras,
    required this.excelRow,
    required this.excelFilePath,
  }) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(widget.cameras.first, ResolutionPreset.max);

    try {
      await _controller!.initialize();
    } catch (e) {
      print('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text('扫描文档')),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          if (_isProcessing) ...[
            Container(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePicture,
        child: Icon(Icons.camera),
      ),
    );
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final image = await _controller!.takePicture();
      final croppedFile = await _cropImage(image.path);
      if (croppedFile != null) {
        final pdfPath = await _generatePdf(croppedFile, widget.excelRow);
        await _processWithAI(pdfPath, widget.excelRow);
      }
    } catch (e) {
      print('Error taking picture: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<File?> _cropImage(String imagePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatioPresets: [CropAspectRatioPreset.original],
      lockAspectRatio: false,
    );
    return croppedFile;
  }

  Future<String> _generatePdf(File imageFile, ExcelRow row) async {
    final pdfBytes = await PdfService.generatePdfFromImage(imageFile);
    final fileName = '${row.fileName}.pdf';
    final pdfPath = await _savePdf(pdfBytes, fileName);
    return pdfPath;
  }

  Future<String> _savePdf(Uint8List pdfBytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$fileName';
    await File(path).writeAsBytes(pdfBytes);
    return path;
  }

  Future<void> _processWithAI(String pdfPath, ExcelRow row) async {
    final aiResponse = await AIService.processWithAI(
      pdfPath: pdfPath,
      question: row.question,
    );

    // 更新Excel文件
    await FileService.updateExcelWithAIResponse(
      excelFilePath: widget.excelFilePath,
      rowId: row.id,
      aiResponse: aiResponse,
    );

    // 返回首页
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('处理完成！')));
  }
}
