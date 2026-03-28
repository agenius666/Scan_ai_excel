import 'dart:async';

import 'package:flutter/services.dart';

class ShareImportService {
  static const MethodChannel _channel = MethodChannel('scanexcel/share_import');
  static const EventChannel _eventChannel = EventChannel('scanexcel/share_import_events');

  Future<String?> getInitialSharedFile() async {
    final result = await _channel.invokeMethod<String>('getInitialSharedFile');
    return result;
  }

  Stream<String> watchIncomingSharedFiles() {
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }
}
