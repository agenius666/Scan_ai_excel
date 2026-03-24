class AiConfig {
  const AiConfig({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    required this.timeoutSeconds,
  });

  final String endpoint;
  final String apiKey;
  final String model;
  final int timeoutSeconds;

  static const AiConfig defaults = AiConfig(
    endpoint: 'https://api.openai.com/v1/chat/completions',
    apiKey: '',
    model: 'gpt-4.1-mini',
    timeoutSeconds: 120,
  );

  AiConfig copyWith({
    String? endpoint,
    String? apiKey,
    String? model,
    int? timeoutSeconds,
  }) {
    return AiConfig(
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }

  Map<String, String> toMap() {
    return {
      'endpoint': endpoint,
      'apiKey': apiKey,
      'model': model,
      'timeoutSeconds': timeoutSeconds.toString(),
    };
  }

  factory AiConfig.fromMap(Map<String, String> map) {
    return AiConfig(
      endpoint: map['endpoint']?.trim().isNotEmpty == true
          ? map['endpoint']!.trim()
          : defaults.endpoint,
      apiKey: map['apiKey'] ?? '',
      model: map['model']?.trim().isNotEmpty == true
          ? map['model']!.trim()
          : defaults.model,
      timeoutSeconds: int.tryParse(map['timeoutSeconds'] ?? '') ??
          defaults.timeoutSeconds,
    );
  }
}
