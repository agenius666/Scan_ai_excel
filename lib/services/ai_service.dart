import 'package:flutter_gemma/flutter_gemma.dart';
import 'dart:io';

class AIService {
  static Future<String> processWithAI({
    required String pdfPath,
    required String question,
  }) async {
    // 初始化Gemma模型
    final modelManager = FlutterGemmaPlugin.instance.modelManager;
    await modelManager.downloadModelFromNetwork(MODEL_URL);

    // 读取PDF内容（简化版，实际需要PDF解析）
    final pdfContent = 'PDF内容摘要：这里是文档的主要内容...';

    // 构建问题
    final fullQuestion = '$question\n\n文档内容：$pdfContent';

    // 调用AI模型
    final response = await FlutterGemmaPlugin.instance.chat(
      messages: [Message(role: 'user', content: fullQuestion)],
    );

    return response.choices.first.message.content;
  }
}
