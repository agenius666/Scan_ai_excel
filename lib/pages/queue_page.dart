import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/scan_task.dart';
import 'result_page.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tasks = controller.tasks
            .where(
              (task) => task.status == TaskStatus.queued ||
                  task.status == TaskStatus.checking ||
                  task.status == TaskStatus.done ||
                  task.status == TaskStatus.failed,
            )
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('核验队列')),
          body: tasks.isEmpty
              ? const Center(child: Text('当前没有核验任务'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Card(
                      child: ListTile(
                        title: Text(task.taskName),
                        subtitle: Text(
                          '${task.status.label}${task.aiResult != null ? ' · ${task.aiResult!.summary}' : task.errorMessage != null ? ' · ${task.errorMessage}' : ''}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ResultPage(
                              controller: controller,
                              taskRowIndex: task.rowIndex,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
