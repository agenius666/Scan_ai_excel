import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import 'label_value.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前规则',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LabelValue(label: 'Sheet', value: controller.excelRule.sheetName),
            LabelValue(
              label: '表头行号',
              value: (controller.excelRule.headerRowIndex + 1).toString(),
            ),
            LabelValue(
              label: '任务名称列',
              value: controller.excelRule.taskNameColumn,
            ),
            LabelValue(
              label: 'PDF命名列',
              value: controller.excelRule.pdfNameColumn,
            ),
            LabelValue(
              label: '核验字段',
              value: controller.excelRule.checkColumns.join(' / '),
            ),
            LabelValue(
              label: '结果写回列',
              value: controller.excelRule.resultColumnName,
            ),
          ],
        ),
      ),
    );
  }
}
