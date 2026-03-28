import 'dart:io';

import 'package:path_provider/path_provider.dart';

class StorageService {
  Future<Directory> getBaseDownloadDirectory() async {
    if (Platform.isAndroid) {
      final candidates = <String>[
        '/storage/emulated/0/Download',
        '/sdcard/Download',
      ];
      for (final path in candidates) {
        final dir = Directory(path);
        if (await dir.exists()) {
          return dir;
        }
      }
    }

    return getApplicationDocumentsDirectory();
  }

  Future<Directory> getExportDirectory({String? configuredBasePath}) async {
    final baseDir = configuredBasePath?.trim().isNotEmpty == true
        ? Directory(configuredBasePath!.trim())
        : await getBaseDownloadDirectory();
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    final exportDir = Directory('${baseDir.path}${Platform.pathSeparator}ScanExcel');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  Future<Directory> getPrivateAppDirectory() async {
    return getApplicationSupportDirectory();
  }
}
