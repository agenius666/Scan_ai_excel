import 'package:flutter/material.dart';

class TaskHeaderCard extends StatelessWidget {
  const TaskHeaderCard({
    super.key,
    required this.title,
    required this.statusText,
    this.statusChipText,
    this.statusColor,
    this.fileName,
    this.pageCount,
    this.summary,
    this.errorText,
  });

  final String title;
  final String statusText;
  final String? statusChipText;
  final Color? statusColor;
  final String? fileName;
  final int? pageCount;
  final String? summary;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipColor = statusColor ?? colorScheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (statusChipText != null)
                  Chip(
                    label: Text(statusChipText!),
                    backgroundColor: chipColor.withOpacity(0.12),
                    side: BorderSide(color: chipColor),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(statusText),
            if (fileName != null && fileName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('文件名：$fileName'),
            ],
            if (pageCount != null) ...[
              const SizedBox(height: 4),
              Text('页数：$pageCount'),
            ],
            if (summary != null && summary!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(summary!),
            ],
            if (errorText != null && errorText!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                errorText!,
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
