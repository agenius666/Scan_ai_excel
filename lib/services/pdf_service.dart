import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:typed_data';

class PdfService {
  static Future<Uint8List> generatePdfFromImage(File imageFile) async {
    final imageBytes = imageFile.readAsBytesSync();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Image(pw.MemoryImage(imageBytes));
        },
      ),
    );

    return pdf.save();
  }
}
