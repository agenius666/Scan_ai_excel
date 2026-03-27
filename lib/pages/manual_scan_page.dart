import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/scanned_page.dart';
import '../services/native_document_service.dart';

class ManualScanPage extends StatefulWidget {
  const ManualScanPage({
    super.key,
    required this.fileNameStem,
    this.maxPages = 20,
  });

  final String fileNameStem;
  final int maxPages;

  @override
  State<ManualScanPage> createState() => _ManualScanPageState();
}

class _ManualScanPageState extends State<ManualScanPage> {
  CameraController? _cameraController;
  Future<void>? _initializeFuture;
  List<CameraDescription> _cameras = const [];
  final List<ScannedPage> _pages = [];

  final NativeDocumentService _nativeDocumentService = NativeDocumentService();

  bool _loading = true;
  bool _capturing = false;
  bool _flashOn = false;
  String? _folderPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _setupCamera() async {
    try {
      _cameras = await availableCameras();
      final camera = _cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      final initializeFuture = controller.initialize();
      await initializeFuture;
      await controller.setFlashMode(FlashMode.off);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _initializeFuture = initializeFuture;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '相机初始化失败：$e';
        _loading = false;
      });
    }
  }

  Future<String> _ensureFolder() async {
    if (_folderPath != null) return _folderPath!;
    final docsDir = await getApplicationDocumentsDirectory();
    final now = DateTime.now().millisecondsSinceEpoch;
    final dir = Directory(
      '${docsDir.path}/scans/${_sanitize(widget.fileNameStem)}_$now',
    );
    await dir.create(recursive: true);
    _folderPath = dir.path;
    return dir.path;
  }

  Future<void> _capturePage() async {
    final controller = _cameraController;
    final initializeFuture = _initializeFuture;
    if (controller == null || initializeFuture == null || _capturing) return;

    setState(() {
      _capturing = true;
    });

    try {
      await initializeFuture;
      final file = await controller.takePicture();
      if (!mounted) return;

      final result = await Navigator.of(context).push<_PageCaptureResult>(
        MaterialPageRoute(
          builder: (_) => _CapturedPageEditor(
            sourcePath: file.path,
            pageNumber: _pages.length + 1,
          ),
        ),
      );

      if (result == null) {
        return;
      }

      final folder = await _ensureFolder();
      final target = File('$folder/page_${result.pageNumber}.jpg');
      await File(result.outputPath).copy(target.path);

      if (!mounted) return;
      setState(() {
        _pages.add(ScannedPage.fromPath(target.path, result.pageNumber));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null) return;

    final next = !_flashOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() {
        _flashOn = next;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切换闪光灯失败：$e')),
      );
    }
  }

  Future<void> _deletePage(int index) async {
    final page = _pages[index];
    try {
      final file = File(page.path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _pages.removeAt(index);
    });
  }

  Future<void> _retakePage(int index) async {
    await _deletePage(index);
    await _capturePage();
  }

  void _finish() {
    Navigator.of(context).pop(_pages.map((e) => e.path).toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('扫描：${widget.fileNameStem}'),
        actions: [
          TextButton(
            onPressed: _pages.isEmpty ? null : _finish,
            child: Text(
              '完成',
              style: TextStyle(
                color: _pages.isEmpty ? Colors.white54 : Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final controller = _cameraController;
    if (controller == null) {
      return const Center(
        child: Text('相机不可用', style: TextStyle(color: Colors.white)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.78,
                    height: MediaQuery.of(context).size.height * 0.52,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '拍照后可自动裁边与透视矫正；也可手动拖拽四角微调。',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final canCapture = !_capturing && _pages.length < widget.maxPages;

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pages.isNotEmpty)
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _PageThumbnail(
                      page: page,
                      onDelete: () => _deletePage(index),
                      onRetake: () => _retakePage(index),
                    );
                  },
                ),
              ),
            if (_pages.isNotEmpty) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleFlash,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
                    label: Text(_flashOn ? '闪光灯开' : '闪光灯关'),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: canCapture ? _capturePage : null,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: canCapture ? Colors.white : Colors.white24,
                      border: Border.all(color: Colors.white54, width: 4),
                    ),
                    child: _capturing
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _pages.isEmpty ? null : _finish,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text('完成 (${_pages.length})'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _pages.length >= widget.maxPages
                  ? '已达到最大页数 ${widget.maxPages}'
                  : '已拍摄 ${_pages.length} 页',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  String _sanitize(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}

class _PageThumbnail extends StatelessWidget {
  const _PageThumbnail({
    required this.page,
    required this.onDelete,
    required this.onRetake,
  });

  final ScannedPage page;
  final VoidCallback onDelete;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(
                File(page.path),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '第 ${page.pageNumber} 页',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                IconButton(
                  onPressed: onRetake,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: '重拍',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: '删除',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageCaptureResult {
  const _PageCaptureResult({
    required this.outputPath,
    required this.pageNumber,
  });

  final String outputPath;
  final int pageNumber;
}

class _CapturedPageEditor extends StatefulWidget {
  const _CapturedPageEditor({
    required this.sourcePath,
    required this.pageNumber,
  });

  final String sourcePath;
  final int pageNumber;

  @override
  State<_CapturedPageEditor> createState() => _CapturedPageEditorState();
}

class _CapturedPageEditorState extends State<_CapturedPageEditor> {
  img.Image? _decoded;
  File? _previewFile;
  List<Offset>? _corners;
  final NativeDocumentService _nativeDocumentService = NativeDocumentService();

  bool _loading = true;
  bool _saving = false;
  int? _draggingIndex;
  Size _imageSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.sourcePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('无法解析图片');
      }
      final normalized = _normalizeOrientation(decoded);
      final tempDir = await getTemporaryDirectory();
      final previewPath = '${tempDir.path}/preview_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(previewPath).writeAsBytes(img.encodeJpg(normalized, quality: 90));
      final nativeCorners = await _nativeDetectCorners(widget.sourcePath);
      final corners = nativeCorners ?? _defaultCorners(normalized.width.toDouble(), normalized.height.toDouble());

      if (!mounted) return;
      setState(() {
        _decoded = normalized;
        _previewFile = File(previewPath);
        _corners = corners;
        _imageSize = Size(normalized.width.toDouble(), normalized.height.toDouble());
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载图片失败：$e')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<List<Offset>?> _nativeDetectCorners(String imagePath) async {
    final values = await _nativeDocumentService.detectDocumentCorners(imagePath);
    if (values == null || values.length != 8) return null;
    return [
      Offset(values[0], values[1]),
      Offset(values[2], values[3]),
      Offset(values[4], values[5]),
      Offset(values[6], values[7]),
    ];
  }

  img.Image _normalizeOrientation(img.Image input) {
    final baked = img.bakeOrientation(input);
    if (baked.height >= baked.width) {
      return baked;
    }
    return img.copyRotate(baked, angle: 90);
  }

  List<Offset> _defaultCorners(double width, double height) {
    final insetX = width * 0.08;
    final insetY = height * 0.06;
    return [
      Offset(insetX, insetY),
      Offset(width - insetX, insetY),
      Offset(width - insetX, height - insetY),
      Offset(insetX, height - insetY),
    ];
  }

  void _rotate(int angle) {
    final decoded = _decoded;
    final corners = _corners;
    if (decoded == null) return;
    final oldWidth = decoded.width.toDouble();
    final oldHeight = decoded.height.toDouble();
    final rotated = img.copyRotate(decoded, angle: angle);
    final tempPath = '${Directory.systemTemp.path}/preview_${DateTime.now().millisecondsSinceEpoch}.jpg';
    File(tempPath).writeAsBytesSync(img.encodeJpg(rotated, quality: 90));

    List<Offset>? rotatedCorners;
    if (corners != null && corners.length == 4) {
      Offset mapPoint(Offset p) {
        if (angle == 90) {
          return Offset(oldHeight - p.dy, p.dx);
        }
        if (angle == -90) {
          return Offset(p.dy, oldWidth - p.dx);
        }
        if (angle == 180 || angle == -180) {
          return Offset(oldWidth - p.dx, oldHeight - p.dy);
        }
        return p;
      }

      final mapped = corners.map(mapPoint).toList(growable: false);
      final sorted = _sortCorners(mapped);
      rotatedCorners = sorted;
    }

    setState(() {
      _decoded = rotated;
      _previewFile = File(tempPath);
      _imageSize = Size(rotated.width.toDouble(), rotated.height.toDouble());
      _corners = rotatedCorners ?? _defaultCorners(_imageSize.width, _imageSize.height);
    });
  }

  Future<void> _save() async {
    final decoded = _decoded;
    final corners = _corners;
    if (decoded == null || corners == null || _saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final cropped = _perspectiveCrop(decoded, corners);
      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/scanned_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(outPath).writeAsBytes(img.encodeJpg(cropped, quality: 92));

      if (!mounted) return;
      Navigator.of(context).pop(
        _PageCaptureResult(outputPath: outPath, pageNumber: widget.pageNumber),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  img.Image _perspectiveCrop(img.Image source, List<Offset> corners) {
    if (corners.length != 4) {
      return _cropByBounds(source, corners);
    }

    final topWidth = (corners[1] - corners[0]).distance;
    final bottomWidth = (corners[2] - corners[3]).distance;
    final leftHeight = (corners[3] - corners[0]).distance;
    final rightHeight = (corners[2] - corners[1]).distance;

    final targetWidth = math.max(1, math.max(topWidth, bottomWidth).round());
    final targetHeight = math.max(1, math.max(leftHeight, rightHeight).round());

    final dst = img.Image(width: targetWidth, height: targetHeight);

    for (var y = 0; y < targetHeight; y++) {
      final v = targetHeight == 1 ? 0.0 : y / (targetHeight - 1);
      final left = Offset.lerp(corners[0], corners[3], v)!;
      final right = Offset.lerp(corners[1], corners[2], v)!;
      for (var x = 0; x < targetWidth; x++) {
        final u = targetWidth == 1 ? 0.0 : x / (targetWidth - 1);
        final sample = Offset.lerp(left, right, u)!;
        final sx = sample.dx.clamp(0, source.width - 1).round();
        final sy = sample.dy.clamp(0, source.height - 1).round();
        dst.setPixel(x, y, source.getPixel(sx, sy));
      }
    }
    return dst;
  }

  img.Image _cropByBounds(img.Image source, List<Offset> corners) {
    final xs = corners.map((e) => e.dx).toList()..sort();
    final ys = corners.map((e) => e.dy).toList()..sort();
    final left = xs.first.clamp(0, source.width - 1).round();
    final right = xs.last.clamp(1, source.width.toDouble()).round();
    final top = ys.first.clamp(0, source.height - 1).round();
    final bottom = ys.last.clamp(1, source.height.toDouble()).round();
    final width = math.max(1, right - left);
    final height = math.max(1, bottom - top);
    return img.copyCrop(source, x: left, y: top, width: width, height: height);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('第 ${widget.pageNumber} 页裁边'),
        actions: [
          TextButton(
            onPressed: _loading || _saving ? null : _save,
            child: Text(
              _saving ? '保存中' : '确认',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _loading || _previewFile == null || _corners == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fitted = applyBoxFit(
                          BoxFit.contain,
                          _imageSize,
                          Size(constraints.maxWidth, constraints.maxHeight),
                        );
                        final renderSize = fitted.destination;
                        final offsetX = (constraints.maxWidth - renderSize.width) / 2;
                        final offsetY = (constraints.maxHeight - renderSize.height) / 2;

                        return GestureDetector(
                          onPanStart: (details) {
                            final local = details.localPosition;
                            final point = _fromDisplay(local, renderSize, offsetX, offsetY);
                            final index = _findNearestCorner(point);
                            setState(() {
                              _draggingIndex = index;
                            });
                          },
                          onPanUpdate: (details) {
                            final index = _draggingIndex;
                            if (index == null) return;
                            final point = _fromDisplay(
                              details.localPosition,
                              renderSize,
                              offsetX,
                              offsetY,
                            );
                            setState(() {
                              _corners![index] = Offset(
                                point.dx.clamp(0, _imageSize.width),
                                point.dy.clamp(0, _imageSize.height),
                              );
                            });
                          },
                          onPanEnd: (_) {
                            setState(() {
                              _draggingIndex = null;
                            });
                          },
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.file(_previewFile!, fit: BoxFit.contain),
                              ),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _CornerOverlayPainter(
                                    corners: _toDisplayCorners(renderSize, offsetX, offsetY),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _loading ? null : () => _rotate(-90),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Icon(Icons.rotate_left),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _loading ? null : () => _rotate(90),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Icon(Icons.rotate_right),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _loading ? null : () => _rotate(180),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Icon(Icons.flip),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        setState(() {
                                          _corners = _defaultCorners(
                                            _imageSize.width,
                                            _imageSize.height,
                                          );
                                        });
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Icon(Icons.crop_free),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _loading || _saving ? null : _save,
                            icon: const Icon(Icons.check),
                            label: const Text('使用当前裁边'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Offset> _sortCorners(List<Offset> points) {
    final sorted = [...points]..sort((a, b) => (a.dx + a.dy).compareTo(b.dx + b.dy));
    final tl = sorted.first;
    final br = sorted.last;
    final remaining = points.where((p) => p != tl && p != br).toList();
    remaining.sort((a, b) => (a.dy - a.dx).compareTo(b.dy - b.dx));
    final tr = remaining.first;
    final bl = remaining.last;
    return [tl, tr, br, bl];
  }

  int _findNearestCorner(Offset imagePoint) {
    var minDistance = double.infinity;
    var minIndex = 0;
    for (var i = 0; i < _corners!.length; i++) {
      final distance = (imagePoint - _corners![i]).distanceSquared;
      if (distance < minDistance) {
        minDistance = distance;
        minIndex = i;
      }
    }
    return minIndex;
  }

  Offset _fromDisplay(Offset local, Size renderSize, double offsetX, double offsetY) {
    final x = ((local.dx - offsetX) / renderSize.width) * _imageSize.width;
    final y = ((local.dy - offsetY) / renderSize.height) * _imageSize.height;
    return Offset(x, y);
  }

  List<Offset> _toDisplayCorners(Size renderSize, double offsetX, double offsetY) {
    return _corners!
        .map(
          (corner) => Offset(
            offsetX + (corner.dx / _imageSize.width) * renderSize.width,
            offsetY + (corner.dy / _imageSize.height) * renderSize.height,
          ),
        )
        .toList(growable: false);
  }
}

class _CornerOverlayPainter extends CustomPainter {
  const _CornerOverlayPainter({required this.corners});

  final List<Offset> corners;

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    final polygon = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fill = Paint()
      ..color = const Color(0x2233B5E5)
      ..style = PaintingStyle.fill;

    final handle = Paint()
      ..color = const Color(0xFF33B5E5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, polygon);

    for (final corner in corners) {
      canvas.drawCircle(corner, 10, handle);
      canvas.drawCircle(
        corner,
        18,
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CornerOverlayPainter oldDelegate) {
    return oldDelegate.corners != corners;
  }
}
