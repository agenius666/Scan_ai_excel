import 'package:flutter/material.dart';

import '../pages/manual_scan_page.dart';

class ScannerService {
  Future<List<String>> scanToPermanentImages({
    required BuildContext context,
    required String fileNameStem,
    int maxPages = 20,
  }) async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => ManualScanPage(fileNameStem: fileNameStem),
      ),
    );

    if (result == null || result.isEmpty) {
      return const [];
    }

    if (result.length > maxPages) {
      return result.take(maxPages).toList();
    }

    return result;
  }
}