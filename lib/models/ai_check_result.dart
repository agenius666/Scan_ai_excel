class FieldCheckResult {
  const FieldCheckResult({
    required this.expected,
    required this.found,
    required this.pass,
    required this.note,
  });

  final String expected;
  final String found;
  final bool? pass;
  final String note;

  factory FieldCheckResult.fromMap(Map<String, dynamic> map) {
    return FieldCheckResult(
      expected: (map['expected'] ?? '').toString(),
      found: (map['found'] ?? '').toString(),
      pass: map['pass'] is bool ? map['pass'] as bool : null,
      note: (map['note'] ?? '').toString(),
    );
  }
}

class AiCheckResult {
  const AiCheckResult({
    required this.finalPass,
    required this.summary,
    required this.fields,
    required this.rawText,
    required this.json,
  });

  final bool? finalPass;
  final String summary;
  final Map<String, FieldCheckResult> fields;
  final String rawText;
  final Map<String, dynamic>? json;

  String toExcelCellText() {
    final status = finalPass == true
        ? '通过'
        : finalPass == false
            ? '不通过'
            : '未判定';
    return '$status | $summary';
  }

  factory AiCheckResult.fromModelResponse({
    required String rawText,
    required Map<String, dynamic>? parsedJson,
    required Map<String, String> fallbackExpectedValues,
  }) {
    if (parsedJson == null) {
      return AiCheckResult(
        finalPass: null,
        summary: rawText.trim().isEmpty ? '模型未返回有效内容' : rawText.trim(),
        fields: const {},
        rawText: rawText,
        json: null,
      );
    }

    final fields = <String, FieldCheckResult>{};
    final dynamic rawFields = parsedJson['fields'];
    if (rawFields is Map) {
      for (final entry in rawFields.entries) {
        if (entry.value is Map<String, dynamic>) {
          fields[entry.key.toString()] =
              FieldCheckResult.fromMap(entry.value as Map<String, dynamic>);
        } else if (entry.value is Map) {
          fields[entry.key.toString()] = FieldCheckResult.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }

    final bool? finalPass = parsedJson['final_pass'] is bool
        ? parsedJson['final_pass'] as bool
        : null;
    final String summary = (parsedJson['summary'] ?? '').toString().trim();

    if (fields.isEmpty && fallbackExpectedValues.isNotEmpty) {
      for (final entry in fallbackExpectedValues.entries) {
        fields[entry.key] = FieldCheckResult(
          expected: entry.value,
          found: '',
          pass: null,
          note: '',
        );
      }
    }

    return AiCheckResult(
      finalPass: finalPass,
      summary: summary.isEmpty ? '模型已返回 JSON，但 summary 为空' : summary,
      fields: fields,
      rawText: rawText,
      json: parsedJson,
    );
  }
}
