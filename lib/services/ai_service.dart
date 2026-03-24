import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ai_check_result.dart';
import '../models/ai_config.dart';
import '../models/excel_rule.dart';

class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AiCheckResult> checkDocument({
    required AiConfig config,
    required ExcelRule rule,
    required Map<String, String> rowData,
    required List<String> imagePaths,
  }) async {
    if (config.apiKey.trim().isEmpty) {
      throw Exception('请先在“我的”页面填写 API Key。');
    }
    if (config.endpoint.trim().isEmpty) {
      throw Exception('请先在“我的”页面填写完整接口地址。');
    }
    if (config.model.trim().isEmpty) {
      throw Exception('请先在“我的”页面填写模型名称。');
    }
    if (imagePaths.isEmpty) {
      throw Exception('没有可用于识别的扫描图片。');
    }

    final prompt = _buildPrompt(rule, rowData);
    final content = <Map<String, dynamic>>[
      {
        'type': 'text',
        'text': prompt,
      },
    ];

    for (final imagePath in imagePaths) {
      final bytes = await File(imagePath).readAsBytes();
      final mime = _guessMimeType(imagePath);
      final base64Data = base64Encode(bytes);
      content.add(
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:$mime;base64,$base64Data',
          },
        },
      );
    }

    final uri = Uri.parse(config.endpoint.trim());
    final payload = {
      'model': config.model.trim(),
      'temperature': 0,
      'messages': [
        {
          'role': 'system',
          'content':
              '你是文档核验助手。严格只返回一个 JSON 对象，不要输出 Markdown，不要输出额外解释。',
        },
        {
          'role': 'user',
          'content': content,
        },
      ],
    };

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.apiKey.trim()}',
          },
          body: jsonEncode(payload),
        )
        .timeout(Duration(seconds: config.timeoutSeconds));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        '模型接口调用失败（${response.statusCode}）：${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = _extractMessageContent(decoded).trim();
    final parsedJson = _tryParseJson(rawText);

    return AiCheckResult.fromModelResponse(
      rawText: rawText,
      parsedJson: parsedJson,
      fallbackExpectedValues: {
        for (final key in rule.checkColumns) key: rowData[key] ?? '',
      },
    );
  }

  String _buildPrompt(ExcelRule rule, Map<String, String> rowData) {
    final fieldsBlock = rule.checkColumns
        .map((column) => '- $column: ${rowData[column] ?? ''}')
        .join('\n');

    var prompt = rule.promptTemplate.replaceAll('{{fields_block}}', fieldsBlock);

    for (final entry in rowData.entries) {
      prompt = prompt.replaceAll('{{${entry.key}}}', entry.value);
    }

    return prompt;
  }

  String _extractMessageContent(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = message['content'];
          if (content is String) {
            return content;
          }
          if (content is List) {
            final buffer = StringBuffer();
            for (final item in content) {
              if (item is Map<String, dynamic>) {
                final text = item['text'];
                if (text != null) {
                  buffer.writeln(text.toString());
                }
              }
            }
            return buffer.toString();
          }
        }
      }
    }
    return decoded.toString();
  }

  Map<String, dynamic>? _tryParseJson(String rawText) {
    if (rawText.isEmpty) {
      return null;
    }

    try {
      final direct = jsonDecode(rawText);
      if (direct is Map<String, dynamic>) {
        return direct;
      }
      if (direct is Map) {
        return Map<String, dynamic>.from(direct);
      }
    } catch (_) {
      // ignore, try substring extraction below
    }

    final firstBrace = rawText.indexOf('{');
    final lastBrace = rawText.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
      return null;
    }

    final candidate = rawText.substring(firstBrace, lastBrace + 1);
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void dispose() {
    _client.close();
  }
}
