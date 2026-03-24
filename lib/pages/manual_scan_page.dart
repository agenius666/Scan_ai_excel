import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_document_scanner/flutter_document_scanner.dart';
import 'package:path_provider/path_provider.dart';

class ManualScanPage extends StatefulWidget {
  const ManualScanPage({
    super.key,
    required this.fileNameStem,
  });

  final String fileNameStem;

  @override
  State<ManualScanPage> createState() => _ManualScanPageState();
}

class _ManualScanPageState extends State<ManualScanPage> {
  final DocumentScannerController _controller = DocumentScannerController();

  bool _isSaving = false;
  int _pageIndex = 1;
  final List<String> _savedPaths = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> _ensureFolder() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final now = DateTime.now().millisecondsSinceEpoch;
    final dir = Directory(
      '${docsDir.path}/scans/${_sanitize(widget.fileNameStem)}_$now',
    );
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> _saveImage(Uint8List bytes) async {
    if (_isSaving) return;
    _isSaving = true;

    try {
      final folder = _savedPaths.isEmpty
          ? await _ensureFolder()
          : File(_savedPaths.first).parent.path;

      final file = File('$folder/page_$_pageIndex.jpg');
      await file.writeAsBytes(bytes, flush: true);
      _savedPaths.add(file.path);

      if (!mounted) return;
      final addMore = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('本页已保存'),
          content: Text('已保存第 $_pageIndex 页，是否继续扫描下一页？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('完成'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续扫描'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (addMore == true) {
        setState(() {
          _pageIndex += 1;
        });
        _controller.changePage(AppPages.takePhoto);
      } else {
        Navigator.pop(context, _savedPaths);
      }
    } finally {
      _isSaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('扫描：${widget.fileNameStem}'),
      ),
      body: DocumentScanner(
        controller: _controller,
        onSave: (Uint8List imageBytes) async {
          await _saveImage(imageBytes);
        },
      ),
    );
  }

  String _sanitize(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}