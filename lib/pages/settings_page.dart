import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/ai_config.dart';
import '../models/excel_rule.dart';
import '../services/save_path_service.dart';
import '../utils/rule_utils.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AiConfig? _lastAiConfig;
  ExcelRule? _lastExcelRule;
  String? _lastSaveBasePath;
  bool _promptExpanded = false;
  final _formKey = GlobalKey<FormState>();
  final SavePathService _savePathService = SavePathService();

  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _timeoutController;
  late final TextEditingController _savePathController;

  late final TextEditingController _sheetController;
  late final TextEditingController _headerRowController;
  late final TextEditingController _taskNameController;
  late final TextEditingController _pdfNameController;
  late final TextEditingController _checkColumnsController;
  late final TextEditingController _resultColumnController;
  late final TextEditingController _promptTemplateController;

  String _selectedTreeUri = '';

  @override
  void initState() {
    super.initState();
    final ai = widget.controller.aiConfig;
    final rule = widget.controller.defaultExcelRule;
    _lastAiConfig = ai;
    _lastExcelRule = rule;
    _lastSaveBasePath = widget.controller.saveBasePath;

    _endpointController = TextEditingController(text: ai.endpoint);
    _apiKeyController = TextEditingController(text: ai.apiKey);
    _modelController = TextEditingController(text: ai.model);
    _timeoutController = TextEditingController(text: ai.timeoutSeconds.toString());
    _savePathController = TextEditingController(text: widget.controller.saveBasePath.isEmpty ? '/storage/emulated/0/Download' : widget.controller.saveBasePath);
    _selectedTreeUri = widget.controller.saveTreeUri;

    _sheetController = TextEditingController(text: rule.sheetName);
    _headerRowController = TextEditingController(text: (rule.headerRowIndex + 1).toString());
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
    _savePathController.dispose();
    _sheetController.dispose();
    _headerRowController.dispose();
    _taskNameController.dispose();
    _pdfNameController.dispose();
    _checkColumnsController.dispose();
    _resultColumnController.dispose();
    _promptTemplateController.dispose();
    super.dispose();
  }

  void _syncFromControllerIfNeeded() {
    final ai = widget.controller.aiConfig;
    final rule = widget.controller.defaultExcelRule;
    final saveBasePath = widget.controller.saveBasePath;
    final shouldSync = !identical(ai, _lastAiConfig) || !identical(rule, _lastExcelRule) || saveBasePath != _lastSaveBasePath;
    if (!shouldSync) return;

    _endpointController.text = ai.endpoint;
    _apiKeyController.text = ai.apiKey;
    _modelController.text = ai.model;
    _timeoutController.text = ai.timeoutSeconds.toString();
    _savePathController.text = saveBasePath.isEmpty ? '/storage/emulated/0/Download' : saveBasePath;
    _selectedTreeUri = widget.controller.saveTreeUri;

    _sheetController.text = rule.sheetName;
    _headerRowController.text = (rule.headerRowIndex + 1).toString();
    _taskNameController.text = rule.taskNameColumn;
    _pdfNameController.text = rule.pdfNameColumn;
    _checkColumnsController.text = rule.checkColumnsCsv;
    _resultColumnController.text = rule.resultColumnName;
    _promptTemplateController.text = rule.promptTemplate;

    _lastAiConfig = ai;
    _lastExcelRule = rule;
    _lastSaveBasePath = saveBasePath;
  }

  @override
  Widget build(BuildContext context) {
    _syncFromControllerIfNeeded();
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
                    TextFormField(controller: _endpointController, decoration: const InputDecoration(labelText: '接口地址', hintText: 'https://api.openai.com/v1/chat/completions'), validator: (value) => (value == null || value.trim().isEmpty) ? '请填写接口地址' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _apiKeyController, decoration: const InputDecoration(labelText: 'API Key'), obscureText: true),
                    const SizedBox(height: 12),
                    TextFormField(controller: _modelController, decoration: const InputDecoration(labelText: '模型名'), validator: (value) => (value == null || value.trim().isEmpty) ? '请填写模型名' : null),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _timeoutController,
                      decoration: const InputDecoration(labelText: '超时秒数'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final seconds = int.tryParse((value ?? '').trim());
                        if (seconds == null || seconds <= 0) return '请填写大于 0 的超时秒数';
                        if (seconds > 600) return '超时秒数建议不要超过 600';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('支持两类接口：OpenAI-compatible /chat/completions，以及 Anthropic /messages。会根据你填写的 endpoint 自动匹配请求格式。', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('建议优先使用支持图片输入的多模态模型。', style: Theme.of(context).textTheme.bodySmall),
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
                    Text('保存路径', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _savePathController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: '基础保存路径',
                        suffixIcon: IconButton(onPressed: _pickSavePath, icon: const Icon(Icons.folder_open_outlined)),
                      ),
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
                    TextFormField(controller: _sheetController, decoration: const InputDecoration(labelText: 'Sheet 名'), validator: (value) => (value == null || value.trim().isEmpty) ? '请填写 Sheet 名' : null),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _headerRowController,
                      decoration: const InputDecoration(labelText: '表头所在行（从 1 开始）'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final row = int.tryParse((value ?? '').trim());
                        if (row == null || row <= 0) return '表头所在行必须是大于 0 的整数';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: _taskNameController, decoration: const InputDecoration(labelText: '任务名称列'), validator: (value) => (value == null || value.trim().isEmpty) ? '请填写任务名称列' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _pdfNameController, decoration: const InputDecoration(labelText: 'PDF 命名列'), validator: (value) => (value == null || value.trim().isEmpty) ? '请填写 PDF 命名列' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _checkColumnsController, decoration: const InputDecoration(labelText: '核验字段（逗号分隔）', hintText: '客户名称,金额,日期'), validator: (value) => parseCheckColumns(value ?? '').isEmpty ? '请至少填写一个核验字段' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _resultColumnController, decoration: const InputDecoration(labelText: '结果列名'), validator: (value) => (value == null || value.trim().isEmpty) ? '请填写结果列名' : null),
                    const SizedBox(height: 8),
                    Text('如果原始 Excel 中不存在这个结果列，系统会在写回时自动补列。', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Prompt 模板'),
                      trailing: Icon(_promptExpanded ? Icons.expand_less : Icons.expand_more),
                      onTap: () => setState(() => _promptExpanded = !_promptExpanded),
                    ),
                    if (_promptExpanded) ...[
                      TextFormField(controller: _promptTemplateController, decoration: const InputDecoration(labelText: 'Prompt 模板', alignLabelWithHint: true), maxLines: 14),
                      const SizedBox(height: 8),
                      Text('模板支持 {{fields_block}} 和 {{列名}} 变量。', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _handleSave, icon: const Icon(Icons.save_outlined), label: const Text('保存设置')),
            const SizedBox(height: 20),
            Text('作者：李文博（t.lwb.net.cn）', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSavePath() async {
    final result = await _savePathService.pickBaseDirectory();
    if (result == null) return;
    _selectedTreeUri = result.uri;
    _savePathController.text = result.displayPath;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

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
      checkColumns: parseCheckColumns(_checkColumnsController.text),
      resultColumnName: _resultColumnController.text.trim(),
      promptTemplate: _promptTemplateController.text,
    );

    final session = widget.controller.session;
    if (session != null) {
      final validation = widget.controller.validateExcelRuleAgainstCurrentSession(rule);
      final message = validation.buildMessage(rule);
      if (message != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$message')));
        return;
      }
    }

    await widget.controller.saveSettings(
      aiConfig: aiConfig,
      excelRule: rule,
      saveBasePath: _savePathController.text.trim(),
      saveTreeUri: _selectedTreeUri,
    );
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存，后续新导入文件会使用这份默认规则')));
  }
}
