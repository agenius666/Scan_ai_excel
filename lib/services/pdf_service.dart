import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'storage_service.dart';

class PdfService {
  PdfService({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  final StorageService _storageService;

  Future<String> generatePdf({
    required List<String> imagePaths,
    required String fileNameStem,
  }) async {
    final pdf = pw.Document();

    for (final imagePath in imagePaths) {
      final imageBytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(imageBytes);
      final isLandscape = decoded != null && decoded.width > decoded.height;
      final image = pw.MemoryImage(imageBytes);
      pdf.addPage(
        pw.Page(
          pageFormat: isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final dir = await _storageService.getDownloadDirectory();
    final stamp = _timestamp();
    final outputPath = '${dir.path}/${_sanitize(fileNameStem)}_$stamp.pdf';
    final outputFile = File(outputPath);
    final bytes = await pdf.save();
    await outputFile.writeAsBytes(bytes, flush: true);
    return outputFile.path;
  }

  Future<String> saveCopyToDownloads(String path) async {
    final source = File(path);
    final dir = await _storageService.getDownloadDirectory();
    final target = File('${dir.path}/${source.uri.pathSegments.last}');
    if (source.path != target.path) {
      await source.copy(target.path);
    }
    return target.path;
  }

  Future<Uint8List> loadPdfBytes(String path) {
    return File(path).readAsBytes();
  }

  String _sanitize(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
