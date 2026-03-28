import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/scan_task.dart';
import '../widgets/empty_state_card.dart';
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
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    EmptyStateCard(
                      icon: Icons.playlist_play_outlined,
                      message: '当前还没有进入核验队列的任务。先扫描并开始核验，任务就会出现在这里。',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('当前共有 ${tasks.length} 条队列相关任务（含排队中 / 核验中 / 已完成 / 失败）。'),
                        ),
                      );
                    }
                    final task = tasks[index - 1];
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
