import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/app_controller.dart';
import '../widgets/empty_state_card.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('历史任务')),
          body: controller.history.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    EmptyStateCard(
                      icon: Icons.history_outlined,
                      message: '还没有历史记录。完成一次核验后，这里会显示任务摘要。',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.history.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('共 ${controller.history.length} 条历史记录，按最近完成时间展示。'),
                        ),
                      );
                    }
                    final item = controller.history[index - 1];
                    final createdAt = DateTime.tryParse(item.createdAt);
                    final timeText = createdAt == null ? item.createdAt : DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt);
                    return Card(
                      child: ListTile(
                        title: Text(item.taskName),
                        subtitle: Text('${item.status} · $timeText\n${item.summary}'),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
