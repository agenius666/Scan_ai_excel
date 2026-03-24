import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../controllers/app_controller.dart';

class PdfPreviewPage extends StatelessWidget {
  const PdfPreviewPage({
    super.key,
    required this.controller,
    required this.pdfPath,
    required this.title,
  });

  final AppController controller;
  final String pdfPath;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PDF预览 - $title')),
      body: PdfPreview(
        canDebug: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: false,
        allowSharing: false,
        build: (format) async {
          final bytes = await controller.loadPdfBytes(pdfPath);
          return Uint8List.fromList(bytes);
        },
      ),
    );
  }
}
