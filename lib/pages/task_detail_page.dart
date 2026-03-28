import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/scan_task.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/task_header_card.dart';
import 'scan_review_page.dart';

class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({
    super.key,
    required this.controller,
    required this.taskRowIndex,
  });

  final AppController controller;
  final int taskRowIndex;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final task = controller.taskByRowIndex(taskRowIndex);
        if (task == null) {
          return const Scaffold(body: Center(child: Text('任务不存在。')));
        }

        return Scaffold(
          appBar: AppBar(title: Text('任务详情 - ${task.taskName}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TaskHeaderCard(
                title: task.taskName,
                statusText: '任务状态：${task.status.label}',
                fileName: '${task.pdfFileNameStem}.pdf',
                pageCount: task.imagePaths.length,
                summary: task.aiResult == null ? null : '结果：${task.aiResult!.summary}',
                errorText: task.errorMessage,
              ),
              const SizedBox(height: 12),
              Text('扫描图片预览', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (task.imagePaths.isEmpty)
                const EmptyStateCard(
                  icon: Icons.photo_library_outlined,
                  message: '还没有扫描图片。先完成扫描，再回来查看详情。',
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: task.imagePaths.asMap().entries.map((entry) {
                    return GestureDetector(
                      onTap: () => _openImagePreview(context, task.imagePaths, entry.key),
                      child: Container(
                        width: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: AspectRatio(
                                aspectRatio: 3 / 4,
                                child: Image.file(
                                  File(entry.value),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('第 ${entry.key + 1} 页'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('返回主页'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: task.imagePaths.isEmpty
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ScanReviewPage(
                                    controller: controller,
                                    taskRowIndex: task.rowIndex,
                                  ),
                                ),
                              ),
                      icon: const Icon(Icons.tune),
                      label: const Text('进入扫描确认'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openImagePreview(BuildContext context, List<String> imagePaths, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImagePreviewPage(imagePaths: imagePaths, initialIndex: initialIndex),
      ),
    );
  }
}

class _ImagePreviewPage extends StatefulWidget {
  const _ImagePreviewPage({required this.imagePaths, required this.initialIndex});

  final List<String> imagePaths;
  final int initialIndex;

  @override
  State<_ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<_ImagePreviewPage> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.imagePaths.length,
          itemBuilder: (context, index) {
            return InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: Image.file(File(widget.imagePaths[index]), fit: BoxFit.contain),
              ),
            );
          },
        ),
      ),
    );
  }
}
