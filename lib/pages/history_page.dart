import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';

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
              ? const Center(child: Text('暂无历史记录'))
              : ListView.separated(
                  itemCount: controller.history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = controller.history[index];
                    return ListTile(
                      title: Text(item.taskName),
                      subtitle: Text('${item.status} · ${item.createdAt}\n${item.summary}'),
                      isThreeLine: true,
                    );
                  },
                ),
        );
      },
    );
  }
}
