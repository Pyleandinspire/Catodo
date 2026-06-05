import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'llm_provider_registry.dart';

class AIConfig {
  final String providerId;
  final String apiKey;
  final String baseUrl;
  final String modelName;

  AIConfig({
    this.providerId = 'custom',
    required this.apiKey,
    required this.baseUrl,
    required this.modelName,
  });

  bool get isValid =>
      apiKey.isNotEmpty && baseUrl.isNotEmpty && modelName.isNotEmpty;

  LLMProvider get provider => LLMProviderRegistry.getById(providerId);
}

class AIService {
  final AIConfig config;
  final Dio _dio;
  final LLMProvider _provider;

  AIService(this.config)
    : _provider = config.provider,
      _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
        ),
      );

  @visibleForTesting
  String get fullApiUrl => '${config.baseUrl}${_provider.apiPath}';

  Future<Map<String, dynamic>?> requestStructuredOutput({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    try {
      final data = <String, dynamic>{
        'model': config.modelName,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': _provider.defaultTemperature,
      };

      if (_provider.supportsJsonMode) {
        data['response_format'] = {'type': 'json_object'};
      } else {
        data['messages'][0] = {
          'role': 'system',
          'content':
              '$systemPrompt\n\n【重要】你必须只返回纯 JSON 格式，不要包含任何 markdown 代码块标记。',
        };
      }

      final response = await _dio.post(fullApiUrl, data: data);

      final String rawContent =
          response.data['choices'][0]['message']['content'];
      return jsonDecode(rawContent) as Map<String, dynamic>;
    } on DioException catch (e) {
      final errorMsg = _parseError(e);
      print('AI API 请求失败: $errorMsg');
      print('  请求 URL: $fullApiUrl');
      return null;
    } catch (e) {
      print('AI 服务异常: $e');
      print('  请求 URL: $fullApiUrl');
      return null;
    }
  }

  String _parseError(DioException e) {
    final statusCode = e.response?.statusCode;
    final responseBody = e.response?.data;
    String detail = '';
    if (responseBody is Map) {
      detail = responseBody['error']?['message']?.toString() ?? '';
    }

    switch (statusCode) {
      case 401:
        return '认证失败：API Key 无效或已过期';
      case 403:
        return '访问被拒绝：请检查 API Key 权限';
      case 404:
        return '端点未找到：请检查 Base URL 和模型名称${detail.isNotEmpty ? ' ($detail)' : ''}';
      case 429:
        return '请求频率超限：请稍后再试';
      case 500:
        return '服务器内部错误：请稍后再试';
      case 503:
        return '服务暂时不可用：请稍后再试';
      default:
        return '请求失败 ($statusCode): ${e.message ?? e.type.name}';
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
    final systemPrompt =
        '''
你是一位温暖、富有极强共情心的心理咨询师，同时也是一位时间管理教练。
用户的任务['$taskTitle']本应在['${dueDate.toString()}']完成，但现在已经超时了。用户目前可能感到自责、焦虑或有些拖延。
请遵循以下对话指南：
1. 绝对不要指责用户，首先使用温柔的语气认可他们之前付出的努力，缓解他们的挫败感。
2. 采用引导式提问（例如："是不是这个任务拆解得不够具体？"或"过程中遇到了什么意外阻碍吗？"），帮助用户厘清原因。
3. 给出1-2条非常具体的、微小的、能立刻上手的行动建议（例如：先坐在书桌前写5分钟字）。
请保持语气短小精悍、温暖治愈，不要长篇大论。
返回JSON: {"response": "你的回复"}
''';

    final result = await requestStructuredOutput(
      systemPrompt: systemPrompt,
      userPrompt: '我需要帮助处理这个超时任务。',
    );

    return result?['response'] as String?;
  }
}
