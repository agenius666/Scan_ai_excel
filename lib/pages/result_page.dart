import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/ai_check_result.dart';
import '../models/scan_task.dart';
import '../widgets/task_header_card.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({
    super.key,
    required this.controller,
    required this.taskRowIndex,
  });

  final AppController controller;
  final int taskRowIndex;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _rawExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final task = widget.controller.taskByRowIndex(widget.taskRowIndex);
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '模型原始返回',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          trailing: Icon(_rawExpanded ? Icons.expand_less : Icons.expand_more),
                          onTap: () => setState(() => _rawExpanded = !_rawExpanded),
                        ),
                        if (_rawExpanded) ...[
                          const SizedBox(height: 8),
                          SelectableText(result.rawText),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回'),
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

    return TaskHeaderCard(
      title: task.taskName,
      statusText: '任务状态：${task.status.label}',
      statusChipText: statusLabel,
      statusColor: statusColor,
      fileName: task.pdfDisplayPath ?? task.pdfPath ?? '尚未生成',
      summary: result?.summary ?? task.errorMessage ?? '暂无模型结果',
      errorText: task.errorMessage,
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
