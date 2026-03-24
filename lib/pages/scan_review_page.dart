import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/scan_task.dart';
import 'pdf_preview_page.dart';
import 'result_page.dart';

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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '任务信息',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('文件名：${task.pdfFileNameStem}.pdf'),
                      const SizedBox(height: 4),
                      Text('页数：${task.imagePaths.length}'),
                      if (task.errorMessage?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          task.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '扫描图片预览',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (task.imagePaths.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('还没有扫描图片。'),
                  ),
                )
              else
                ...task.imagePaths.asMap().entries.map(
                      (entry) => Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('第 ${entry.key + 1} 页'),
                            ),
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              child: Image.file(
                                File(entry.value),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: controller.busy ? null : () => _rescan(context, task),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('重新扫描'),
                  ),
                  FilledButton.icon(
                    onPressed: controller.busy || task.imagePaths.isEmpty
                        ? null
                        : () => _runAi(context, task),
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: const Text('生成 PDF 并开始核验'),
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
                    label: const Text('查看已生成 PDF'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _runAi(BuildContext context, ScanTask task) async {
    try {
      final doneTask = await controller.processScannedTask(task);
      if (!context.mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultPage(
            controller: controller,
            taskRowIndex: doneTask.rowIndex,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}
