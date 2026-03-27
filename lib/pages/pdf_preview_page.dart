import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

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
      appBar: AppBar(
        title: Text('PDF预览 - $title'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final bytes = await controller.loadPdfBytes(pdfPath);
              await Printing.sharePdf(
                bytes: Uint8List.fromList(bytes),
                filename: '$title.pdf',
              );
            },
            icon: const Icon(Icons.share_outlined),
            label: const Text('分享'),
          ),
        ],
      ),
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
