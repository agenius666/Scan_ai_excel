import 'dart:io';

import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:path_provider/path_provider.dart';

class ScannerService {
  Future<List<String>> scanToPermanentImages({
    required String fileNameStem,
    int maxPages = 20,
  }) async {
    final result = await FlutterDocScanner().getScannedDocumentAsImages(
      page: maxPages,
      imageFormat: ImageFormat.jpeg,
      quality: 0.9,
    );

    if (result == null || result.images.isEmpty) {
      return const [];
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final now = DateTime.now().millisecondsSinceEpoch;
    final folder = Directory(
      '${docsDir.path}/scans/${_sanitize(fileNameStem)}_$now',
    );
    await folder.create(recursive: true);

    final copiedPaths = <String>[];
    for (var i = 0; i < result.images.length; i++) {
      final sourcePath = result.images[i];
      final source = File(sourcePath);
      final ext = _extensionOf(source.path);
      final targetPath = '${folder.path}/page_${i + 1}$ext';
      final copied = await source.copy(targetPath);
      copiedPaths.add(copied.path);
    }

    return copiedPaths;
  }

  String _sanitize(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _extensionOf(String path) {
    final index = path.lastIndexOf('.');
    if (index == -1) {
      return '.jpg';
    }
    return path.substring(index);
  }
}
