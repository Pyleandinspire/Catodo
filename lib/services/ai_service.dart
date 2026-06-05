import 'dart:convert';
import 'package:dio/dio.dart';

class AIConfig {
  final String apiKey;
  final String baseUrl;
  final String modelName;

  AIConfig({
    required this.apiKey,
    required this.baseUrl,
    required this.modelName,
  });

  bool get isValid {
    return apiKey.isNotEmpty && baseUrl.isNotEmpty && modelName.isNotEmpty;
  }
}

class AIService {
  final AIConfig config;
  final Dio _dio;

  AIService(this.config) : _dio = Dio() {
    _dio.options.headers = {
      'Authorization': 'Bearer ${config.apiKey}',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>?> requestStructuredOutput({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    try {
      final response = await _dio.post(
        '${config.baseUrl}/v1/chat/completions',
        data: {
          'model': config.modelName,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt}
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.3,
        },
      );

      final String rawContent = response.data['choices'][0]['message']['content'];
      return jsonDecode(rawContent) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> decomposeTask(String taskTitle) async {
    const systemPrompt = '''
你是一个严谨的个人效能专家。请将用户输入的宏大任务拆解为3-5个具体可执行的子任务。
你必须返回标准的JSON格式，结构体如下，不要包含任何多余的markdown标记或Markdown代码块：
{
  "tasks": [
    {"title": "子任务名称", "priority": 1, "estimatedMinutes": 30},
    {"title": "子任务名称", "priority": 2, "estimatedMinutes": 45}
  ]
}
注意：priority用1(不重要)到3(极为重要)表示。
''';

    final result = await requestStructuredOutput(
      systemPrompt: systemPrompt,
      userPrompt: taskTitle,
    );

    return result?['tasks'] as List<Map<String, dynamic>>?;
  }

  Future<String?> getOverdueSupport(String taskTitle, DateTime dueDate) async {
    final systemPrompt = '''
你是一位温暖、富有极强共情心的心理咨询师，同时也是一位时间管理教练。
用户的任务['$taskTitle']本应在['${dueDate.toString()}']完成，但现在已经超时了。用户目前可能感到自责、焦虑或有些拖延。
请遵循以下对话指南：
1. 绝对不要指责用户，首先使用温柔的语气认可他们之前付出的努力，缓解他们的挫败感。
2. 采用引导式提问（例如：“是不是这个任务拆解得不够具体？”或“过程中遇到了什么意外阻碍吗？”），帮助用户厘清原因。
3. 给出1-2条非常具体的、微小的、能立刻上手的行动建议（例如：先坐在书桌前写5分钟字）。
请保持语气短小精悍、温暖治愈，不要长篇大论。
''';

    final result = await requestStructuredOutput(
      systemPrompt: systemPrompt,
      userPrompt: '我需要帮助处理这个超时任务。',
    );

    return result?['response'] as String?;
  }
}