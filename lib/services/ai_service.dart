import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'llm_provider_registry.dart';
import 'ai_agent.dart';

class AIConfig {
  final String providerId;
  final String apiKey;
  final String apiUrl;
  final String modelName;

  AIConfig({
    this.providerId = 'custom',
    required this.apiKey,
    required this.apiUrl,
    required this.modelName,
  });

  bool get isValid =>
      apiKey.isNotEmpty && apiUrl.isNotEmpty && modelName.isNotEmpty;

  LLMProvider get provider => LLMProviderRegistry.getById(providerId);
}

/// 单轮聊天消息（用于多轮上下文记忆）
///
/// `role` 限定为 `'user'` 或 `'assistant'`；`'system'` 由 [AIService] 内部拼装，
/// 调用方不应在 history 中放 system 角色。
class ChatTurn {
  final String role;
  final String content;

  const ChatTurn({required this.role, required this.content});

  const ChatTurn.user(String content) : this(role: 'user', content: content);
  const ChatTurn.assistant(String content)
    : this(role: 'assistant', content: content);

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// 截断聊天历史，仅保留最近 [maxTurns] 轮（一轮 = 一条 user + 一条 assistant，约 2 条 message）。
///
/// 现阶段以 message 数量近似（保留 `maxTurns * 2` 条），日后可改为按 token 估算。
/// 始终从最早的一端丢弃，以确保保留到最近的上下文。
@visibleForTesting
List<ChatTurn> truncateChatHistory(
  List<ChatTurn> history, {
  int maxTurns = 8,
}) {
  final maxMessages = maxTurns * 2;
  if (history.length <= maxMessages) return List.of(history);
  return history.sublist(history.length - maxMessages);
}

/// 连接测试结果
class ConnectionTestResult {
  final bool success;
  final String message;
  final String? detail;

  ConnectionTestResult({
    required this.success,
    required this.message,
    this.detail,
  });
}

/// 调用 AI 时可能出现的错误类型分级。
///
/// UI 层据此区分提示与可恢复操作（重试 / 跳设置 / 换模型）。
enum AiErrorType {
  unauthorized,
  forbidden,
  notFound,
  badRequest,
  rateLimited,
  serverError,
  network,
  timeout,
  parseFailed,
  unknown,
}

/// AI 调用失败的结构化错误信息。
class AiCallError {
  final AiErrorType type;
  final String message;
  final String? detail;
  final int? statusCode;

  const AiCallError({
    required this.type,
    required this.message,
    this.detail,
    this.statusCode,
  });

  @override
  String toString() =>
      'AiCallError($type, status=$statusCode, message=$message, detail=$detail)';
}

/// `requestStructuredOutput` 的详细返回值：data 与 error 互斥。
typedef AiStructuredResult = ({Map<String, dynamic>? data, AiCallError? error});

/// `requestAgentActionWithHistory` 的详细返回值。
typedef AiAgentResult = ({AgentResponse response, AiCallError? error});

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
  String get fullApiUrl => config.apiUrl;

  /// 从 apiUrl 推导出 models 端点 URL
  ///
  /// 规则：将末尾的 /chat/completions 替换为 /models
  /// 例如：https://api.openai.com/v1/chat/completions → https://api.openai.com/v1/models
  @visibleForTesting
  String get modelsEndpoint {
    final url = fullApiUrl;
    if (url.endsWith('/chat/completions')) {
      return url.replaceAll('/chat/completions', '/models');
    }
    // 如果 URL 不以 /chat/completions 结尾，尝试在最后一个 / 前插入
    final lastSlash = url.lastIndexOf('/');
    if (lastSlash > 0) {
      return '${url.substring(0, lastSlash)}/models';
    }
    return '$url/models';
  }

  /// 从厂商 API 动态获取可用模型列表
  ///
  /// 通过 GET /models 端点获取，返回模型 ID 列表。
  /// 如果请求失败，返回空列表。
  Future<List<String>> fetchModels() async {
    if (config.apiUrl.isEmpty || config.apiKey.isEmpty) {
      return [];
    }

    try {
      final response = await _dio.get(
        modelsEndpoint,
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      final data = response.data;
      if (data is! Map) return [];

      final modelList = data['data'];
      if (modelList is! List) return [];

      final models = <String>[];
      for (final item in modelList) {
        if (item is Map) {
          final id = item['id'];
          if (id is String && id.isNotEmpty) {
            models.add(id);
          }
        }
      }

      models.sort();
      return models;
    } catch (e) {
      debugPrint('获取模型列表失败: $e');
      return [];
    }
  }

  /// 请求结构化 JSON 输出
  ///
  /// 兼容策略：
  /// - 不发送 response_format（最大兼容性，所有厂商都支持）
  /// - 通过 prompt 强制要求 JSON 格式
  /// - 宽容解析响应：兼容 markdown 代码块包裹、多余空白等
  ///
  /// 失败时返回 null；如需结构化错误信息，使用 [requestStructuredOutputDetailed]。
  Future<Map<String, dynamic>?> requestStructuredOutput({
    required String systemPrompt,
    required String userPrompt,
    List<ChatTurn> history = const [],
  }) async {
    final r = await requestStructuredOutputDetailed(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      history: history,
    );
    return r.data;
  }

  /// 详细版：返回 (data, error)；data 与 error 至多一个非空。
  Future<AiStructuredResult> requestStructuredOutputDetailed({
    required String systemPrompt,
    required String userPrompt,
    List<ChatTurn> history = const [],
  }) async {
    try {
      final messages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content':
              '$systemPrompt\n\n【重要】你必须只返回纯 JSON 格式，不要包含任何 markdown 代码块标记（如 ```json ```）或其他非 JSON 内容。',
        },
        for (final t in history) t.toJson(),
        {'role': 'user', 'content': userPrompt},
      ];

      final data = <String, dynamic>{
        'model': config.modelName,
        'messages': messages,
        'temperature': _provider.defaultTemperature,
      };

      final response = await _dio.post(fullApiUrl, data: data);

      final rawContent = _extractContent(response.data);
      if (rawContent == null) {
        debugPrint('AI API 响应格式无法解析: ${response.data}');
        return (
          data: null,
          error: const AiCallError(
            type: AiErrorType.parseFailed,
            message: 'AI 返回了无法解析的响应',
            detail: '响应中未找到可识别的 content 字段，可能是模型与端点不匹配。',
          ),
        );
      }

      final parsed = _parseJsonContent(rawContent);
      if (parsed == null) {
        return (
          data: null,
          error: AiCallError(
            type: AiErrorType.parseFailed,
            message: 'AI 返回了非 JSON 格式',
            detail: '原始响应（截断）: ${_truncateForDisplay(rawContent)}',
          ),
        );
      }
      return (data: parsed, error: null);
    } on DioException catch (e) {
      final err = mapDioExceptionForTest(e);
      debugPrint('AI API 请求失败: ${err.message} / ${err.detail}');
      debugPrint('  请求 URL: $fullApiUrl');
      return (data: null, error: err);
    } catch (e) {
      debugPrint('AI 服务异常: $e');
      debugPrint('  请求 URL: $fullApiUrl');
      return (
        data: null,
        error: AiCallError(
          type: AiErrorType.unknown,
          message: '未知错误',
          detail: e.toString(),
        ),
      );
    }
  }

  /// 轻量级连接测试
  ///
  /// 发送最简单的请求验证连通性，不依赖 JSON 解析等业务逻辑。
  /// 返回详细的测试结果，便于用户排查问题。
  Future<ConnectionTestResult> testConnection() async {
    // 第一步：验证配置完整性
    if (!config.isValid) {
      return ConnectionTestResult(
        success: false,
        message: '配置不完整',
        detail: '请填写 API URL、API Key 和模型名称',
      );
    }

    // 第二步：验证 URL 格式
    final uri = Uri.tryParse(fullApiUrl);
    if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
      return ConnectionTestResult(
        success: false,
        message: 'API URL 格式无效',
        detail:
            '当前 URL: $fullApiUrl\n应为完整地址，如 https://api.openai.com/v1/chat/completions',
      );
    }

    // 第三步：发送最简请求测试连通性
    try {
      final response = await _dio.post(
        fullApiUrl,
        data: {
          'model': config.modelName,
          'messages': [
            {'role': 'user', 'content': 'hi'},
          ],
          'max_tokens': 5,
        },
      );

      // 验证响应中能提取出内容
      final content = _extractContent(response.data);
      if (content != null) {
        return ConnectionTestResult(
          success: true,
          message: '连接成功',
          detail: '模型 ${config.modelName} 响应正常',
        );
      }

      // 响应格式不标准但请求本身成功了
      return ConnectionTestResult(
        success: true,
        message: '连接成功（响应格式非标准）',
        detail: 'API 可达，但响应结构可能与预期不同。功能可能受影响。',
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final responseBody = e.response?.data;
      String detail = '';

      if (responseBody is Map) {
        // 尝试提取厂商返回的错误信息
        final errorObj = responseBody['error'];
        if (errorObj is Map) {
          detail = errorObj['message']?.toString() ?? '';
        } else if (errorObj is String) {
          detail = errorObj;
        }
        if (detail.isEmpty) {
          detail = responseBody.toString();
        }
      } else if (responseBody != null) {
        detail = responseBody.toString();
      }

      switch (statusCode) {
        case 401:
          return ConnectionTestResult(
            success: false,
            message: 'API Key 无效或已过期',
            detail: detail.isNotEmpty ? '厂商返回: $detail' : '请检查 API Key 是否正确',
          );
        case 403:
          return ConnectionTestResult(
            success: false,
            message: '访问被拒绝',
            detail: detail.isNotEmpty ? '厂商返回: $detail' : '请检查 API Key 权限',
          );
        case 404:
          return ConnectionTestResult(
            success: false,
            message: '端点未找到',
            detail:
                '请检查 API URL 是否正确\n当前 URL: $fullApiUrl\n${detail.isNotEmpty ? '厂商返回: $detail' : ''}',
          );
        case 429:
          return ConnectionTestResult(
            success: true,
            message: '连接正常（请求频率受限）',
            detail: 'API Key 有效，但当前请求频率超限，请稍后再试'
          );
        case 400:
          return ConnectionTestResult(
            success: false,
            message: '请求参数错误',
            detail:
                '可能是模型名称不正确\n当前模型: ${config.modelName}\n${detail.isNotEmpty ? '厂商返回: $detail' : ''}',
          );
        case 500:
        case 502:
        case 503:
          return ConnectionTestResult(
            success: false,
            message: '厂商服务器错误 ($statusCode)',
            detail: '这不是你的配置问题，请稍后再试',
          );
        default:
          final errType = e.type;
          if (errType == DioExceptionType.connectionTimeout ||
              errType == DioExceptionType.connectionError) {
            return ConnectionTestResult(
              success: false,
              message: '无法连接到服务器',
              detail:
                  '请检查:\n1. API URL 是否正确\n2. 网络是否正常\n3. 是否需要代理访问\n当前 URL: $fullApiUrl',
            );
          }
          return ConnectionTestResult(
            success: false,
            message: '请求失败 ($statusCode)',
            detail: detail.isNotEmpty ? '厂商返回: $detail' : e.message ?? '',
          );
      }
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        message: '未知错误',
        detail: e.toString(),
      );
    }
  }

  /// 从响应中提取文本内容，兼容不同厂商的响应格式
  ///
  /// 标准格式: response.data['choices'][0]['message']['content']
  /// 兼容格式:
  /// - choices 为空数组 → 返回 null
  /// - content 为 null → 尝试 tool_calls 等字段
  /// - response.data 直接是字符串
  String? _extractContent(dynamic responseData) {
    if (responseData is! Map) return null;

    // 标准路径: choices[0].message.content
    final choices = responseData['choices'];
    if (choices is List && choices.isNotEmpty) {
      final firstChoice = choices[0];
      if (firstChoice is Map) {
        final message = firstChoice['message'];
        if (message is Map) {
          final content = message['content'];
          if (content is String && content.isNotEmpty) {
            return content;
          }
        }
      }
    }

    // 某些厂商可能用 output 字段
    final output = responseData['output'];
    if (output is Map) {
      final text = output['text'];
      if (text is String && text.isNotEmpty) return text;
      final choices2 = output['choices'];
      if (choices2 is List && choices2.isNotEmpty) {
        final first = choices2[0];
        if (first is Map) {
          final content = first['message']?['content'] ?? first['content'];
          if (content is String && content.isNotEmpty) return content;
        }
      }
    }

    // data 字段（某些代理服务）
    final dataField = responseData['data'];
    if (dataField is String && dataField.isNotEmpty) return dataField;

    return null;
  }

  /// 宽容解析 JSON 内容
  ///
  /// 兼容：
  /// - 纯 JSON 字符串
  /// - 被 ```json ... ``` 包裹的字符串
  /// - 前后有多余空白/换行的字符串
  static Map<String, dynamic>? _parseJsonContent(String raw) {
    var content = raw.trim();

    // 去除 markdown 代码块包裹
    final codeBlockRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = codeBlockRegex.firstMatch(content);
    if (match != null) {
      content = match.group(1)?.trim() ?? content;
    }

    try {
      final parsed = jsonDecode(content);
      if (parsed is Map<String, dynamic>) return parsed;
      return null;
    } catch (_) {
      // 尝试找到第一个 { 和最后一个 } 之间的内容
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          final parsed = jsonDecode(content.substring(start, end + 1));
          if (parsed is Map<String, dynamic>) return parsed;
        } catch (_) {}
      }
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

  /// 请求 Agent 执行操作
  ///
  /// 使用 Agent 专用 system prompt + 任务上下文，
  /// LLM 返回包含 reply 和 actions 的 JSON。
  Future<AgentResponse> requestAgentAction({
    required String userMessage,
    required String context,
  }) async {
    return requestAgentActionWithHistory(
      latestUserMessage: userMessage,
      context: context,
      history: const [],
    );
  }

  /// 多轮版本：在 system 之外携带最近若干轮对话历史。
  ///
  /// [history] 必须只包含 user/assistant 角色，调用前可经 [truncateChatHistory] 截断。
  Future<AgentResponse> requestAgentActionWithHistory({
    required List<ChatTurn> history,
    required String latestUserMessage,
    required String context,
  }) async {
    final r = await requestAgentActionDetailedWithHistory(
      history: history,
      latestUserMessage: latestUserMessage,
      context: context,
    );
    return r.response;
  }

  /// 详细版：返回 (response, error)。失败时 response 为兜底回复，
  /// error 包含 [AiErrorType] 供 UI 分支提示。
  Future<AiAgentResult> requestAgentActionDetailedWithHistory({
    required List<ChatTurn> history,
    required String latestUserMessage,
    required String context,
  }) async {
    final systemPrompt = '$kAgentSystemPrompt\n\n$context';
    final trimmed = truncateChatHistory(history);

    final r = await requestStructuredOutputDetailed(
      systemPrompt: systemPrompt,
      userPrompt: latestUserMessage,
      history: trimmed,
    );

    if (r.error != null) {
      return (
        response: AgentResponse(reply: r.error!.message),
        error: r.error,
      );
    }
    if (r.data == null) {
      return (
        response: const AgentResponse(reply: '抱歉，我暂时无法处理你的请求。'),
        error: const AiCallError(
          type: AiErrorType.unknown,
          message: '未知错误',
        ),
      );
    }
    return (response: AgentResponse.fromJson(r.data!), error: null);
  }

  /// 请求一份时间安排优化建议（PLAN-AI-001-4）。
  ///
  /// [taskContext] 是 buildTaskContext 输出的字符串；可选 [extraNote]
  /// 用于注入"近 14 天逾期/完成统计"等增量信息。
  ///
  /// 返回 record (plan, error)：成功时 plan 非空、error 为 null；
  /// 失败时按 [AiCallError] 分级提示。
  Future<({SchedulingPlan? plan, AiCallError? error})>
      requestSchedulingPlanDetailed({
    required String taskContext,
    String? extraNote,
  }) async {
    final systemPrompt = StringBuffer(kSchedulingSystemPrompt)
      ..writeln()
      ..writeln(taskContext);
    if (extraNote != null && extraNote.isNotEmpty) {
      systemPrompt
        ..writeln()
        ..writeln('【附加信息】')
        ..writeln(extraNote);
    }
    final r = await requestStructuredOutputDetailed(
      systemPrompt: systemPrompt.toString(),
      userPrompt: '请基于上述任务给出优化建议（仅返回 JSON）。',
    );
    if (r.error != null) return (plan: null, error: r.error);
    if (r.data == null) {
      return (
        plan: null,
        error: const AiCallError(
          type: AiErrorType.unknown,
          message: '未知错误',
        ),
      );
    }
    return (plan: SchedulingPlan.fromJson(r.data!), error: null);
  }
}

// ==================== Dio 错误映射工具 ====================

/// 把 [DioException] 映射为 [AiCallError]，供 UI 分级展示与单测使用。
///
/// 暴露为公开顶层函数，避免在私有声明上加 `@visibleForTesting`（lint 警告）。
AiCallError mapDioExceptionForTest(DioException e) {
  final statusCode = e.response?.statusCode;
  final responseBody = e.response?.data;

  String detail = '';
  if (responseBody is Map) {
    final errorObj = responseBody['error'];
    if (errorObj is Map) {
      detail = errorObj['message']?.toString() ?? '';
    } else if (errorObj is String) {
      detail = errorObj;
    }
    if (detail.isEmpty) {
      detail = responseBody.toString();
    }
  } else if (responseBody != null) {
    detail = responseBody.toString();
  }
  detail = _truncateForDisplay(detail);

  // 状态码优先于 DioExceptionType
  switch (statusCode) {
    case 401:
      return AiCallError(
        type: AiErrorType.unauthorized,
        message: 'API Key 无效或已过期',
        detail: detail.isNotEmpty ? detail : null,
        statusCode: 401,
      );
    case 403:
      return AiCallError(
        type: AiErrorType.forbidden,
        message: '访问被拒绝',
        detail: detail.isNotEmpty ? detail : '请检查 API Key 权限',
        statusCode: 403,
      );
    case 404:
      return AiCallError(
        type: AiErrorType.notFound,
        message: '端点不存在或模型名错误',
        detail: detail.isNotEmpty ? detail : '请检查 API URL 与 model 名称',
        statusCode: 404,
      );
    case 400:
      return AiCallError(
        type: AiErrorType.badRequest,
        message: '请求参数错误',
        detail: detail.isNotEmpty ? detail : '可能是模型名称不正确',
        statusCode: 400,
      );
    case 429:
      return AiCallError(
        type: AiErrorType.rateLimited,
        message: '请求太频繁',
        detail: detail.isNotEmpty ? detail : '请稍后再试',
        statusCode: 429,
      );
    case 500:
    case 502:
    case 503:
      return AiCallError(
        type: AiErrorType.serverError,
        message: '厂商服务器错误 ($statusCode)',
        detail: '不是你的配置问题，请稍后再试',
        statusCode: statusCode,
      );
  }

  // 无 status code → 看 DioExceptionType
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return AiCallError(
        type: AiErrorType.timeout,
        message: '网络超时',
        detail: '请稍后重试，或换用更快的模型',
      );
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return AiCallError(
        type: AiErrorType.network,
        message: '无法连接到服务器',
        detail: '请检查 API URL 是否正确，以及网络/代理配置',
      );
    default:
      return AiCallError(
        type: AiErrorType.unknown,
        message: '请求失败',
        detail: e.message ?? e.type.name,
      );
  }
}

String _truncateForDisplay(String s, {int max = 240}) {
  final trimmed = s.trim();
  if (trimmed.length <= max) return trimmed;
  return '${trimmed.substring(0, max - 1)}…';
}
