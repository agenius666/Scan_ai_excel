import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/scan_task.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/task_header_card.dart';
import 'pdf_preview_page.dart';

class ScanReviewPage extends StatelessWidget {
  const ScanReviewPage({
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
          return const Scaffold(
            body: Center(child: Text('任务不存在。')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text('扫描确认 - ${task.taskName}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TaskHeaderCard(
                title: task.taskName,
                statusText: '任务状态：${task.status.label}',
                fileName: '${task.pdfFileNameStem}.pdf',
                pageCount: task.imagePaths.length,
                summary: task.aiResult == null ? null : '结果摘要：${task.aiResult!.summary}',
                errorText: task.errorMessage,
              ),
              const SizedBox(height: 12),
              Text('扫描图片预览', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (task.imagePaths.isEmpty)
                const EmptyStateCard(
                  icon: Icons.photo_library_outlined,
                  message: '还没有扫描图片。先完成扫描，再回来进行核验或生成 PDF。',
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: task.imagePaths.asMap().entries.map((entry) {
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _ImagePreviewPage(
                            imagePaths: task.imagePaths,
                            initialIndex: entry.key,
                          ),
                        ),
                      ),
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
                                child: Image.file(File(entry.value), fit: BoxFit.cover),
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
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: controller.busy || !task.canStartChecking || task.isInFlight
                        ? null
                        : () => _enqueue(context, task),
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: Text(task.isInFlight ? '核验中' : '开始核验'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.busy || task.isInFlight ? null : () => _rescan(context, task),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(task.status == TaskStatus.pending ? '扫描' : '重新扫描'),
                  ),
                  OutlinedButton.icon(
                    onPressed: task.pdfPath == null
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PdfPreviewPage(
                                  controller: controller,
                                  pdfPath: task.pdfPath!,
                                  title: task.taskName,
                                ),
                              ),
                            ),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('查看 PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: task.imagePaths.isEmpty || task.isInFlight
                        ? null
                        : () => _generatePdf(context, task),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(task.pdfPath == null ? '生成 PDF' : '重新生成 PDF'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _rescan(BuildContext context, ScanTask task) async {
    try {
      await controller.scanTask(context, task);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }

  Future<void> _enqueue(BuildContext context, ScanTask task) async {
    try {
      await controller.enqueueTaskForChecking(task);
      if (!context.mounted) return;
      final nextTask = controller.nextTaskAfter(task.rowIndex);
      if (nextTask != null) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ScanReviewPage(controller: controller, taskRowIndex: nextTask.rowIndex),
          ),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }

  Future<void> _generatePdf(BuildContext context, ScanTask task) async {
    try {
      final path = await controller.generatePdfForTask(task);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF 已生成，已保存到：\n$path')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
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
