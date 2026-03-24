import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/ai_check_result.dart';
import '../models/scan_task.dart';
import 'pdf_preview_page.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({
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

        final result = task.aiResult;
        return Scaffold(
          appBar: AppBar(title: Text('核验结果 - ${task.taskName}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(task: task, result: result),
              const SizedBox(height: 12),
              if (result != null && result.fields.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '字段比对',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ...result.fields.entries.map(
                          (entry) => _FieldCard(
                            fieldName: entry.key,
                            value: entry.value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (result != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '模型原始返回',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(result.rawText),
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
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('返回首页'),
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
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.task, required this.result});

  final ScanTask task;
  final AiCheckResult? result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = result?.finalPass == true
        ? Colors.green
        : result?.finalPass == false
            ? colorScheme.error
            : colorScheme.outline;

    final statusLabel = result?.finalPass == true
        ? '通过'
        : result?.finalPass == false
            ? '不通过'
            : '未判定';

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
                    task.taskName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: statusColor.withOpacity(0.12),
                  side: BorderSide(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('状态：${task.status.label}'),
            Text('PDF：${task.pdfPath ?? '尚未生成'}'),
            const SizedBox(height: 8),
            Text(result?.summary ?? '暂无模型结果'),
          ],
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.fieldName, required this.value});

  final String fieldName;
  final FieldCheckResult value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stateColor = value.pass == true
        ? Colors.green
        : value.pass == false
            ? colorScheme.error
            : colorScheme.outline;

    final stateText = value.pass == true
        ? '一致'
        : value.pass == false
            ? '不一致'
            : '未判定';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stateColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fieldName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(
                label: Text(stateText),
                backgroundColor: stateColor.withOpacity(0.12),
                side: BorderSide(color: stateColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('期望值：${value.expected}'),
          const SizedBox(height: 4),
          Text('识别值：${value.found}'),
          if (value.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('说明：${value.note}'),
          ],
        ],
      ),
    );
  }
}
