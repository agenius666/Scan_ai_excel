import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class SavePathPickResult {
  const SavePathPickResult({required this.uri, required this.displayPath});

  final String uri;
  final String displayPath;
}

class TreeWriteResult {
  const TreeWriteResult({required this.uri, required this.displayPath});

  final String uri;
  final String displayPath;

  bool get isContentUri => uri.startsWith('content://');
}

class SavePathService {
  static const MethodChannel _channel = MethodChannel('scanexcel/save_path');

  Future<SavePathPickResult?> pickBaseDirectory() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickBaseDirectory');
    if (result == null) return null;
    final uri = (result['uri'] ?? '').toString();
    final displayPath = (result['displayPath'] ?? '').toString();
    if (uri.isEmpty) return null;
    return SavePathPickResult(uri: uri, displayPath: displayPath);
  }

  Future<bool> openDocumentUri({required String uri, required String mimeType}) async {
    final result = await _channel.invokeMethod<bool>('openDocumentUri', {
      'uri': uri,
      'mimeType': mimeType,
    });
    return result ?? false;
  }

  Future<TreeWriteResult> writeBytesToTree({
    required String treeUri,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('writeBytesToTree', {
      'treeUri': treeUri,
      'fileName': fileName,
      'bytesBase64': base64Encode(bytes),
      'mimeType': mimeType,
    });
    if (result == null) {
      throw Exception('写入目标文件夹失败');
    }
    final uri = (result['uri'] ?? '').toString();
    final displayPath = (result['displayPath'] ?? '').toString();
    if (uri.isEmpty) {
      throw Exception('写入目标文件夹失败');
    }
    return TreeWriteResult(uri: uri, displayPath: displayPath.isEmpty ? uri : displayPath);
  }
}
