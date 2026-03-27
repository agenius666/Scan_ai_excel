import 'package:flutter/services.dart';

class NativeDocumentService {
  static const MethodChannel _channel = MethodChannel('scanexcel/native_document');

  Future<List<double>?> detectDocumentCorners(String imagePath) async {
    final result = await _channel.invokeMethod<List<dynamic>>('detectDocumentCorners', {
      'imagePath': imagePath,
    });
    if (result == null || result.length != 8) {
      return null;
    }
    return result.map((e) => (e as num).toDouble()).toList(growable: false);
  }
}
