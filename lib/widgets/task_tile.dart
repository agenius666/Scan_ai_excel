import 'package:flutter/material.dart';

import '../models/scan_task.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onScan,
    required this.onOpenPdf,
    required this.onOpenResult,
  });

  final ScanTask task;
  final VoidCallback onScan;
  final VoidCallback onOpenPdf;
  final VoidCallback onOpenResult;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = switch (task.status) {
      TaskStatus.pending => colorScheme.outline,
      TaskStatus.scanning => colorScheme.primary,
      TaskStatus.scanned => colorScheme.secondary,
      TaskStatus.checking => colorScheme.tertiary,
      TaskStatus.done => Colors.green,
      TaskStatus.failed => colorScheme.error,
    };

    final subtitle = <String>[];
    for (final entry in task.rowData.entries.take(3)) {
      subtitle.add('${entry.key}: ${entry.value}');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.taskName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(task.status.label),
                  backgroundColor: statusColor.withOpacity(0.12),
                  side: BorderSide(color: statusColor),
                ),
              ],
            ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle.join('   |   ')),
              ),
            if (task.errorMessage?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  task.errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(task.imagePaths.isEmpty ? '开始扫描' : '重新扫描'),
                ),
                OutlinedButton.icon(
                  onPressed: task.pdfPath == null ? null : onOpenPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('查看PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: task.aiResult == null ? null : onOpenResult,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('查看结果'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
