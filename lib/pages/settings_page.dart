import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/ai_config.dart';
import '../models/excel_rule.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _timeoutController;

  late final TextEditingController _sheetController;
  late final TextEditingController _headerRowController;
  late final TextEditingController _taskNameController;
  late final TextEditingController _pdfNameController;
  late final TextEditingController _checkColumnsController;
  late final TextEditingController _resultColumnController;
  late final TextEditingController _promptTemplateController;

  @override
  void initState() {
    super.initState();
    final ai = widget.controller.aiConfig;
    final rule = widget.controller.excelRule;

    _endpointController = TextEditingController(text: ai.endpoint);
    _apiKeyController = TextEditingController(text: ai.apiKey);
    _modelController = TextEditingController(text: ai.model);
    _timeoutController = TextEditingController(text: ai.timeoutSeconds.toString());

    _sheetController = TextEditingController(text: rule.sheetName);
    _headerRowController = TextEditingController(
      text: (rule.headerRowIndex + 1).toString(),
    );
    _taskNameController = TextEditingController(text: rule.taskNameColumn);
    _pdfNameController = TextEditingController(text: rule.pdfNameColumn);
    _checkColumnsController = TextEditingController(text: rule.checkColumnsCsv);
    _resultColumnController = TextEditingController(text: rule.resultColumnName);
    _promptTemplateController = TextEditingController(text: rule.promptTemplate);
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _timeoutController.dispose();
    _sheetController.dispose();
    _headerRowController.dispose();
    _taskNameController.dispose();
    _pdfNameController.dispose();
    _checkColumnsController.dispose();
    _resultColumnController.dispose();
    _promptTemplateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('模型配置', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _endpointController,
                      decoration: const InputDecoration(
                        labelText: '接口地址',
                        hintText: 'https://api.openai.com/v1/chat/completions',
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? '请填写接口地址' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(labelText: 'API Key'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(labelText: '模型名'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? '请填写模型名' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _timeoutController,
                      decoration: const InputDecoration(labelText: '超时秒数'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '支持两类接口：OpenAI-compatible /chat/completions，以及 Anthropic /messages。会根据你填写的 endpoint 自动匹配请求格式。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Excel 规则', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sheetController,
                      decoration: const InputDecoration(labelText: 'Sheet 名'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? '请填写 Sheet 名' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _headerRowController,
                      decoration: const InputDecoration(labelText: '表头所在行（从 1 开始）'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _taskNameController,
                      decoration: const InputDecoration(labelText: '任务名称列'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pdfNameController,
                      decoration: const InputDecoration(labelText: 'PDF 命名列'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _checkColumnsController,
                      decoration: const InputDecoration(
                        labelText: '核验字段（逗号分隔）',
                        hintText: '客户名称,金额,日期',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _resultColumnController,
                      decoration: const InputDecoration(labelText: '结果列名'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _promptTemplateController,
                      decoration: const InputDecoration(
                        labelText: 'Prompt 模板',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 14,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '模板支持 {{fields_block}} 和 {{列名}} 变量。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存设置'),
            ),
            const SizedBox(height: 20),
            Text(
              '作者：李文博\n官方网站：t.lwb.net.cn',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final aiConfig = AiConfig(
      endpoint: _endpointController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
      timeoutSeconds: int.tryParse(_timeoutController.text.trim()) ?? 120,
    );

    final rule = ExcelRule(
      sheetName: _sheetController.text.trim(),
      headerRowIndex: (int.tryParse(_headerRowController.text.trim()) ?? 1) - 1,
      taskNameColumn: _taskNameController.text.trim(),
      pdfNameColumn: _pdfNameController.text.trim(),
      checkColumns: _checkColumnsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      resultColumnName: _resultColumnController.text.trim(),
      promptTemplate: _promptTemplateController.text,
    );

    await widget.controller.saveSettings(aiConfig: aiConfig, excelRule: rule);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );
  }
}
