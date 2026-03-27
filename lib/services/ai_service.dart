import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

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
    final uri = Uri.parse(config.endpoint.trim());
    final payload = await _buildPayload(uri, config, prompt, imagePaths);
    final headers = _buildHeaders(uri, config);

    final response = await _client
        .post(
          uri,
          headers: headers,
          body: jsonEncode(payload),
        )
        .timeout(Duration(seconds: config.timeoutSeconds));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('模型接口调用失败（${response.statusCode}）：${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = _extractMessageContent(decoded).trim();
    final parsedJson = _tryParseJson(rawText);

    if (_looksLikeMissingDocument(parsedJson, rawText)) {
      throw Exception(
        '模型未识别到上传图片。请检查当前接口是否支持多模态图片输入（image_url/base64），或切换到支持视觉输入的模型。原始返回：$rawText',
      );
    }

    return AiCheckResult.fromModelResponse(
      rawText: rawText,
      parsedJson: parsedJson,
      fallbackExpectedValues: {
        for (final key in rule.checkColumns) key: rowData[key] ?? '',
      },
    );
  }

  Map<String, String> _buildHeaders(Uri uri, AiConfig config) {
    final endpoint = uri.toString().toLowerCase();
    if (endpoint.contains('/messages')) {
      return {
        'Content-Type': 'application/json',
        'x-api-key': config.apiKey.trim(),
        'anthropic-version': '2023-06-01',
      };
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config.apiKey.trim()}',
    };
  }

  Future<Map<String, dynamic>> _buildPayload(
    Uri uri,
    AiConfig config,
    String prompt,
    List<String> imagePaths,
  ) async {
    final endpoint = uri.toString().toLowerCase();
    if (endpoint.contains('/messages')) {
      return {
        'model': config.model.trim(),
        'max_tokens': 2048,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              ...await _anthropicImages(imagePaths),
            ],
          },
        ],
      };
    }

    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
    ];
    for (final imagePath in imagePaths) {
      final prepared = await _prepareImage(imagePath);
      content.add({
        'type': 'image_url',
        'image_url': {'url': 'data:${prepared.mime};base64,${prepared.base64}'},
      });
    }

    return {
      'model': config.model.trim(),
      'temperature': 0,
      'messages': [
        {
          'role': 'system',
          'content': '你是文档核验助手。你会收到一张或多张文档扫描图片。必须基于图片内容核验 Excel 字段。严格只返回一个 JSON 对象，不要输出 Markdown，不要输出额外解释，不要要求用户再次提供文档内容。',
        },
        {
          'role': 'user',
          'content': content,
        },
      ],
    };
  }

  Future<List<Map<String, dynamic>>> _anthropicImages(List<String> imagePaths) async {
    final items = <Map<String, dynamic>>[];
    for (final imagePath in imagePaths) {
      final prepared = await _prepareImage(imagePath);
      items.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': prepared.mime,
          'data': prepared.base64,
        },
      });
    }
    return items;
  }

  Future<_PreparedImage> _prepareImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return _PreparedImage(
        base64: base64Encode(bytes),
        mime: _guessMimeType(imagePath),
      );
    }

    final normalized = decoded.height >= decoded.width
        ? decoded
        : img.copyRotate(decoded, angle: 90);
    final resized = normalized.width > 1600
        ? img.copyResize(normalized, width: 1600)
        : normalized;
    final jpg = img.encodeJpg(resized, quality: 88);
    return _PreparedImage(base64: base64Encode(jpg), mime: 'image/jpeg');
  }

  String _buildPrompt(ExcelRule rule, Map<String, String> rowData) {
    final fieldsBlock =
        rule.checkColumns.map((column) => '- $column: ${rowData[column] ?? ''}').join('\n');
    var prompt = rule.promptTemplate.replaceAll('{{fields_block}}', fieldsBlock);
    for (final entry in rowData.entries) {
      prompt = prompt.replaceAll('{{${entry.key}}}', entry.value);
    }
    return '$prompt\n\n请直接基于图片中的文档内容完成核验。你已经收到了文档图片，不要回复“请提供文档内容”。';
  }

  bool _looksLikeMissingDocument(Map<String, dynamic>? parsedJson, String rawText) {
    final lowerRaw = rawText.toLowerCase();
    if (lowerRaw.contains('please provide the document content')) {
      return true;
    }
    if (parsedJson == null) return false;
    final message = (parsedJson['message'] ?? '').toString().toLowerCase();
    final status = (parsedJson['status'] ?? '').toString().toLowerCase();
    return status == 'ready' && message.contains('provide the document content');
  }

  String _extractMessageContent(Map<String, dynamic> decoded) {
    if (decoded['content'] is List) {
      final content = decoded['content'] as List;
      final buf = StringBuffer();
      for (final item in content) {
        if (item is Map && item['text'] != null) {
          buf.writeln(item['text'].toString());
        }
      }
      if (buf.isNotEmpty) return buf.toString();
    }

    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = message['content'];
          if (content is String) return content;
          if (content is List) {
            final buffer = StringBuffer();
            for (final item in content) {
              if (item is Map<String, dynamic> && item['text'] != null) {
                buffer.writeln(item['text'].toString());
              }
            }
            return buffer.toString();
          }
        }
      }
    }

    if (decoded['message'] != null) {
      return decoded['message'].toString();
    }
    return decoded.toString();
  }

  Map<String, dynamic>? _tryParseJson(String rawText) {
    if (rawText.isEmpty) return null;
    try {
      final direct = jsonDecode(rawText);
      if (direct is Map<String, dynamic>) return direct;
      if (direct is Map) return Map<String, dynamic>.from(direct);
    } catch (_) {}
    final firstBrace = rawText.indexOf('{');
    final lastBrace = rawText.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) return null;
    final candidate = rawText.substring(firstBrace, lastBrace + 1);
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
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

class _PreparedImage {
  const _PreparedImage({required this.base64, required this.mime});

  final String base64;
  final String mime;
}
