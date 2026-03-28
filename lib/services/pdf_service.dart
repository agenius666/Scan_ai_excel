import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'save_path_service.dart';
import 'storage_service.dart';

class PdfWriteResult {
  const PdfWriteResult({required this.uri, required this.displayPath, required this.fileName});

  final String uri;
  final String displayPath;
  final String fileName;
}

class PdfService {
  PdfService({StorageService? storageService, SavePathService? savePathService})
      : _storageService = storageService ?? StorageService(),
        _savePathService = savePathService ?? SavePathService();

  final StorageService _storageService;
  final SavePathService _savePathService;

  Future<PdfWriteResult> generatePdf({
    required List<String> imagePaths,
    required String fileNameStem,
    String? saveBasePath,
    String? saveTreeUri,
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
          build: (context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }

    final stamp = _timestamp();
    final fileName = '${_sanitize(fileNameStem)}_$stamp.pdf';
    final bytes = Uint8List.fromList(await pdf.save());

    if (saveTreeUri != null && saveTreeUri.isNotEmpty) {
      final result = await _savePathService.writeBytesToTree(
        treeUri: saveTreeUri,
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      return PdfWriteResult(uri: result.uri, displayPath: result.displayPath, fileName: fileName);
    }

    final dir = await _storageService.getExportDirectory(configuredBasePath: saveBasePath);
    final outputPath = '${dir.path}/$fileName';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(bytes, flush: true);
    return PdfWriteResult(uri: outputFile.path, displayPath: outputFile.path, fileName: fileName);
  }

  Future<String> saveCopyToDownloads(String path, {String? saveBasePath}) async {
    final source = File(path);
    final dir = await _storageService.getExportDirectory(configuredBasePath: saveBasePath);
    final target = File('${dir.path}/${source.uri.pathSegments.last}');
    if (source.path != target.path) {
      await source.copy(target.path);
    }
    return target.path;
  }

  Future<Uint8List> loadPdfBytes(String path) => File(path).readAsBytes();

  String _sanitize(String input) => input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  String _timestamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.month)}${two(now.day)}${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
