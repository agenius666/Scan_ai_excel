import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/ai_config.dart';
import '../models/excel_rule.dart';

class SettingsService {
  SettingsService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _aiPrefix = 'ai_';
  static const _rulePrefix = 'rule_';

  Future<AiConfig> loadAiConfig() async {
    final map = await _storage.readAll();
    final aiMap = <String, String>{
      'endpoint': map['${_aiPrefix}endpoint'] ?? '',
      'apiKey': map['${_aiPrefix}apiKey'] ?? '',
      'model': map['${_aiPrefix}model'] ?? '',
      'timeoutSeconds': map['${_aiPrefix}timeoutSeconds'] ?? '',
    };
    return AiConfig.fromMap(aiMap);
  }

  Future<void> saveAiConfig(AiConfig config) async {
    final map = config.toMap();
    for (final entry in map.entries) {
      await _storage.write(key: '$_aiPrefix${entry.key}', value: entry.value);
    }
  }

  Future<ExcelRule> loadExcelRule() async {
    final map = await _storage.readAll();
    final ruleMap = <String, String>{
      'sheetName': map['${_rulePrefix}sheetName'] ?? '',
      'headerRowIndex': map['${_rulePrefix}headerRowIndex'] ?? '',
      'taskNameColumn': map['${_rulePrefix}taskNameColumn'] ?? '',
      'pdfNameColumn': map['${_rulePrefix}pdfNameColumn'] ?? '',
      'checkColumns': map['${_rulePrefix}checkColumns'] ?? '',
      'resultColumnName': map['${_rulePrefix}resultColumnName'] ?? '',
      'promptTemplate': map['${_rulePrefix}promptTemplate'] ?? '',
    };
    return ExcelRule.fromMap(ruleMap);
  }

  Future<void> saveExcelRule(ExcelRule rule) async {
    final map = rule.toMap();
    for (final entry in map.entries) {
      await _storage.write(key: '$_rulePrefix${entry.key}', value: entry.value);
    }
  }
}
