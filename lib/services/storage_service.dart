import 'dart:io';

import 'package:path_provider/path_provider.dart';

class StorageService {
  Future<Directory> getDownloadDirectory() async {
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

  Future<Directory> getPrivateAppDirectory() async {
    return getApplicationSupportDirectory();
  }
}
