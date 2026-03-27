import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/scan_task.dart';
import '../widgets/summary_card.dart';
import '../widgets/task_tile.dart';
import 'history_page.dart';
import 'pdf_preview_page.dart';
import 'queue_page.dart';
import 'result_page.dart';
import 'scan_review_page.dart';
import 'task_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('ScanExcel')),
          body: Column(
            children: [
              if (controller.busy)
                LinearProgressIndicator(
                  minHeight: 2,
                  borderRadius: BorderRadius.circular(999),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: controller.busy ? null : () => _handleImport(context),
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('导入 XLSX'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: controller.busy || controller.session == null
                                ? null
                                : () => _handleExport(context),
                            icon: const Icon(Icons.save_alt_outlined),
                            label: const Text('导出结果'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => QueuePage(controller: controller)),
                            ),
                            icon: const Icon(Icons.playlist_play_outlined),
                            label: Text(
                              controller.queueRunning
                                  ? '核验队列运行中'
                                  : '核验队列（${controller.queuedCount}）',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HistoryPage(controller: controller),
                              ),
                            ),
                            icon: const Icon(Icons.history_outlined),
                            label: const Text('历史任务'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('当前文件', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(controller.currentExcelName ?? '尚未导入 Excel'),
                            if (controller.lastExportPath != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '最近导出：${controller.lastExportPath}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (controller.currentMessage?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(
                                controller.currentMessage!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SummaryCard(controller: controller),
                    const SizedBox(height: 12),
                    _StatsSection(controller: controller),
                    const SizedBox(height: 16),
                    Text('任务列表', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (controller.tasks.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('请先导入一个符合规则的 xlsx 文件。'),
                        ),
                      )
                    else
                      ...controller.tasks.map(
                        (task) => TaskTile(
                          task: task,
                          onView: () => _openView(context, task),
                          onRescan: () => _handleRescan(context, task),
                          onOpenPdf: () => _openPdf(context, task),
                          onOpenResult: () => _openResult(context, task),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleImport(BuildContext context) async {
    try {
      await controller.importExcel();
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  Future<void> _handleExport(BuildContext context) async {
    try {
      final path = await controller.exportExcel();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出成功：$path')),
      );
    } catch (e) {
      _showError(context, e.toString());
    }
  }

  Future<void> _handleRescan(BuildContext context, ScanTask task) async {
    try {
      final scannedTask = await controller.scanTask(context, task);
      if (!context.mounted || scannedTask == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScanReviewPage(
            controller: controller,
            taskRowIndex: scannedTask.rowIndex,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e.toString());
    }
  }

  void _openView(BuildContext context, ScanTask task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(
          controller: controller,
          taskRowIndex: task.rowIndex,
        ),
      ),
    );
  }

  void _openPdf(BuildContext context, ScanTask task) {
    if (task.pdfPath == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewPage(
          controller: controller,
          pdfPath: task.pdfPath!,
          title: task.taskName,
        ),
      ),
    );
  }

  void _openResult(BuildContext context, ScanTask task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultPage(
          controller: controller,
          taskRowIndex: task.rowIndex,
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('总数', controller.totalCount.toString()),
      ('待处理', controller.pendingCount.toString()),
      ('已扫描', controller.scannedCount.toString()),
      ('排队中', controller.queuedCount.toString()),
      ('核验中', controller.checkingCount.toString()),
      ('已完成', controller.doneCount.toString()),
      ('失败', controller.failedCount.toString()),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats
              .map(
                (item) => Container(
                  width: 100,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1),
                      const SizedBox(height: 6),
                      Text(
                        item.$2,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
