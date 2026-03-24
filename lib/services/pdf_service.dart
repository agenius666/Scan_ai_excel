import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  Future<String> generatePdf({
    required List<String> imagePaths,
    required String fileNameStem,
  }) async {
    final pdf = pw.Document();

    for (final imagePath in imagePaths) {
      final imageBytes = await File(imagePath).readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            return pw.Center(
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${dir.path}/generated_pdfs');
    await pdfDir.create(recursive: true);

    final outputPath = '${pdfDir.path}/${_sanitize(fileNameStem)}.pdf';
    final outputFile = File(outputPath);
    final bytes = await pdf.save();
    await outputFile.writeAsBytes(bytes, flush: true);
    return outputFile.path;
  }

  Future<Uint8List> loadPdfBytes(String path) {
    return File(path).readAsBytes();
  }

  String _sanitize(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
