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
        builder: (_) => ManualScanPage(
          fileNameStem: fileNameStem,
          maxPages: maxPages,
        ),
      ),
    );

    if (result == null || result.isEmpty) {
      return const [];
    }

    return result;
  }
}
