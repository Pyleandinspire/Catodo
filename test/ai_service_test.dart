import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/services/ai_service.dart';
import 'package:catodo/services/llm_provider_registry.dart';

void main() {
  group('AIConfig URL 测试', () {
    test('预设提供商 - DeepSeek URL 直接使用', () {
      final config = AIConfig(
        providerId: 'deepseek',
        apiKey: 'sk-test',
        apiUrl: 'https://api.deepseek.com/v1/chat/completions',
        modelName: 'deepseek-chat',
      );
      final service = AIService(config);
      expect(
        service.fullApiUrl,
        'https://api.deepseek.com/v1/chat/completions',
      );
    });

    test('预设提供商 - OpenAI URL 直接使用', () {
      final config = AIConfig(
        providerId: 'openai',
        apiKey: 'sk-test',
        apiUrl: 'https://api.openai.com/v1/chat/completions',
        modelName: 'gpt-3.5-turbo',
      );
      final service = AIService(config);
      expect(service.fullApiUrl, 'https://api.openai.com/v1/chat/completions');
    });

    test('预设提供商 - 智谱 GLM URL 直接使用', () {
      final config = AIConfig(
        providerId: 'glm',
        apiKey: 'test-key',
        apiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
        modelName: 'glm-4-flash',
      );
      final service = AIService(config);
      expect(
        service.fullApiUrl,
        'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      );
    });

    test('预设提供商 - 千问 URL 直接使用', () {
      final config = AIConfig(
        providerId: 'qwen',
        apiKey: 'sk-test',
        apiUrl:
            'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        modelName: 'qwen-turbo',
      );
      final service = AIService(config);
      expect(
        service.fullApiUrl,
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
      );
    });

    test('预设提供商 - 豆包 URL 直接使用', () {
      final config = AIConfig(
        providerId: 'doubao',
        apiKey: 'test-key',
        apiUrl: 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
        modelName: 'doubao-pro-32k',
      );
      final service = AIService(config);
      expect(
        service.fullApiUrl,
        'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
      );
    });

    test('预设提供商 - Kimi URL 直接使用', () {
      final config = AIConfig(
        providerId: 'moonshot',
        apiKey: 'sk-test',
        apiUrl: 'https://api.moonshot.cn/v1/chat/completions',
        modelName: 'moonshot-v1-8k',
      );
      final service = AIService(config);
      expect(service.fullApiUrl, 'https://api.moonshot.cn/v1/chat/completions');
    });

    test('自定义提供商 - 使用用户输入的完整 apiUrl', () {
      final config = AIConfig(
        providerId: 'custom',
        apiKey: 'sk-test',
        apiUrl: 'https://my-custom-api.example.com/v1/chat/completions',
        modelName: 'custom-model',
      );
      final service = AIService(config);
      expect(
        service.fullApiUrl,
        'https://my-custom-api.example.com/v1/chat/completions',
      );
    });

    test('默认 providerId 为 custom', () {
      final config = AIConfig(
        apiKey: 'sk-test',
        apiUrl: 'https://test.com/v1/chat/completions',
        modelName: 'test-model',
      );
      expect(config.providerId, 'custom');
      expect(config.provider.id, 'custom');
    });
  });

  group('AIConfig 有效性测试', () {
    test('完整配置有效', () {
      final config = AIConfig(
        apiKey: 'sk-test',
        apiUrl: 'https://test.com/v1/chat/completions',
        modelName: 'test-model',
      );
      expect(config.isValid, true);
    });

    test('缺少 apiKey 无效', () {
      final config = AIConfig(
        apiKey: '',
        apiUrl: 'https://test.com/v1/chat/completions',
        modelName: 'test-model',
      );
      expect(config.isValid, false);
    });

    test('缺少 apiUrl 无效', () {
      final config = AIConfig(
        apiKey: 'sk-test',
        apiUrl: '',
        modelName: 'test-model',
      );
      expect(config.isValid, false);
    });
  });

  group('LLMProviderRegistry 测试', () {
    test('getById 返回正确的提供商', () {
      final provider = LLMProviderRegistry.getById('deepseek');
      expect(provider.name, 'DeepSeek');
      expect(provider.apiUrl, 'https://api.deepseek.com/v1/chat/completions');
    });

    test('未知 id 返回自定义', () {
      final provider = LLMProviderRegistry.getById('unknown');
      expect(provider.id, 'custom');
    });

    test('所有预设提供商都有有效的 apiUrl', () {
      for (final provider in LLMProviderRegistry.providers) {
        if (provider.id != 'custom') {
          expect(
            provider.apiUrl.isNotEmpty,
            true,
            reason: '${provider.name} 的 apiUrl 不应为空',
          );
          expect(
            provider.apiUrl.startsWith('https://'),
            true,
            reason: '${provider.name} 的 apiUrl 应以 https:// 开头',
          );
          expect(
            provider.apiUrl.endsWith('/chat/completions'),
            true,
            reason: '${provider.name} 的 apiUrl 应以 /chat/completions 结尾',
          );
        }
      }
    });
  });

  group('JSON 宽容解析测试', () {
    test('纯 JSON 字符串', () {
      final raw = '{"tasks": [{"title": "test"}]}';
      final parsed = parseJsonForTest(raw);
      expect(parsed, isNotNull);
      expect(parsed!['tasks'], isA<List>());
    });

    test('被 markdown 代码块包裹的 JSON', () {
      final raw = '```json\n{"tasks": [{"title": "test"}]}\n```';
      final parsed = parseJsonForTest(raw);
      expect(parsed, isNotNull);
      expect(parsed!['tasks'], isA<List>());
    });

    test('被 ``` 包裹（无 json 标记）的 JSON', () {
      final raw = '```\n{"tasks": [{"title": "test"}]}\n```';
      final parsed = parseJsonForTest(raw);
      expect(parsed, isNotNull);
      expect(parsed!['tasks'], isA<List>());
    });

    test('前后有多余文字的 JSON', () {
      final raw = 'Here is the result:\n{"tasks": [{"title": "test"}]}\nDone.';
      final parsed = parseJsonForTest(raw);
      expect(parsed, isNotNull);
      expect(parsed!['tasks'], isA<List>());
    });

    test('前后有空白和换行的 JSON', () {
      final raw = '  \n  {"tasks": [{"title": "test"}]}  \n  ';
      final parsed = parseJsonForTest(raw);
      expect(parsed, isNotNull);
      expect(parsed!['tasks'], isA<List>());
    });

    test('无效 JSON 返回 null', () {
      final raw = 'This is not JSON at all';
      final parsed = parseJsonForTest(raw);
      expect(parsed, isNull);
    });

    test('空字符串返回 null', () {
      final parsed = parseJsonForTest('');
      expect(parsed, isNull);
    });
  });

  group('ConnectionTestResult 测试', () {
    test('成功结果', () {
      final result = ConnectionTestResult(
        success: true,
        message: '连接成功',
        detail: '模型 gpt-4o 响应正常',
      );
      expect(result.success, true);
      expect(result.message, '连接成功');
      expect(result.detail, '模型 gpt-4o 响应正常');
    });

    test('失败结果', () {
      final result = ConnectionTestResult(
        success: false,
        message: 'API Key 无效',
        detail: '请检查 API Key 是否正确',
      );
      expect(result.success, false);
      expect(result.message, 'API Key 无效');
    });

    test('无 detail 的结果', () {
      final result = ConnectionTestResult(success: true, message: '连接成功');
      expect(result.detail, isNull);
    });
  });

  group('modelsEndpoint 推导测试', () {
    test('OpenAI - /v1/chat/completions → /v1/models', () {
      final config = AIConfig(
        providerId: 'openai',
        apiKey: 'sk-test',
        apiUrl: 'https://api.openai.com/v1/chat/completions',
        modelName: 'gpt-3.5-turbo',
      );
      final service = AIService(config);
      expect(service.modelsEndpoint, 'https://api.openai.com/v1/models');
    });

    test('DeepSeek - /v1/chat/completions → /v1/models', () {
      final config = AIConfig(
        providerId: 'deepseek',
        apiKey: 'sk-test',
        apiUrl: 'https://api.deepseek.com/v1/chat/completions',
        modelName: 'deepseek-chat',
      );
      final service = AIService(config);
      expect(service.modelsEndpoint, 'https://api.deepseek.com/v1/models');
    });

    test('GLM - /v4/chat/completions → /v4/models', () {
      final config = AIConfig(
        providerId: 'glm',
        apiKey: 'test-key',
        apiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
        modelName: 'glm-4-flash',
      );
      final service = AIService(config);
      expect(
        service.modelsEndpoint,
        'https://open.bigmodel.cn/api/paas/v4/models',
      );
    });

    test(
      '千问 - /compatible-mode/v1/chat/completions → /compatible-mode/v1/models',
      () {
        final config = AIConfig(
          providerId: 'qwen',
          apiKey: 'sk-test',
          apiUrl:
              'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
          modelName: 'qwen-turbo',
        );
        final service = AIService(config);
        expect(
          service.modelsEndpoint,
          'https://dashscope.aliyuncs.com/compatible-mode/v1/models',
        );
      },
    );

    test('豆包 - /v3/chat/completions → /v3/models', () {
      final config = AIConfig(
        providerId: 'doubao',
        apiKey: 'test-key',
        apiUrl: 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
        modelName: 'doubao-pro-32k',
      );
      final service = AIService(config);
      expect(
        service.modelsEndpoint,
        'https://ark.cn-beijing.volces.com/api/v3/models',
      );
    });

    test('自定义 URL 不以 /chat/completions 结尾 - 使用 lastSlash 策略', () {
      final config = AIConfig(
        providerId: 'custom',
        apiKey: 'sk-test',
        apiUrl: 'https://my-api.example.com/v2/completions',
        modelName: 'my-model',
      );
      final service = AIService(config);
      expect(service.modelsEndpoint, 'https://my-api.example.com/v2/models');
    });

    test('所有预设提供商的 modelsEndpoint 都以 /models 结尾', () {
      for (final provider in LLMProviderRegistry.providers) {
        if (provider.id != 'custom') {
          final config = AIConfig(
            providerId: provider.id,
            apiKey: 'test-key',
            apiUrl: provider.apiUrl,
            modelName: provider.defaultModel,
          );
          final service = AIService(config);
          expect(
            service.modelsEndpoint.endsWith('/models'),
            true,
            reason:
                '${provider.name} 的 modelsEndpoint 应以 /models 结尾，实际: ${service.modelsEndpoint}',
          );
        }
      }
    });
  });

  group('ChatTurn / truncateChatHistory 测试', () {
    test('ChatTurn.toJson 输出 role+content', () {
      const turn = ChatTurn.user('你好');
      expect(turn.toJson(), {'role': 'user', 'content': '你好'});
      const turn2 = ChatTurn.assistant('收到');
      expect(turn2.role, 'assistant');
      expect(turn2.content, '收到');
    });

    test('truncateChatHistory: 短于上限时原样返回（且为副本）', () {
      final history = [
        const ChatTurn.user('a'),
        const ChatTurn.assistant('b'),
      ];
      final out = truncateChatHistory(history, maxTurns: 8);
      expect(out.length, 2);
      expect(out, isNot(same(history)));
      expect(out[0].content, 'a');
      expect(out[1].content, 'b');
    });

    test('truncateChatHistory: 超过上限时仅保留最近 maxTurns*2 条', () {
      // 12 条 message（6 轮），maxTurns=4 → 应保留最近 8 条
      final history = <ChatTurn>[];
      for (var i = 0; i < 6; i++) {
        history.add(ChatTurn.user('u$i'));
        history.add(ChatTurn.assistant('a$i'));
      }
      final out = truncateChatHistory(history, maxTurns: 4);
      expect(out.length, 8);
      // 应当从 u2/a2 起到 u5/a5（丢掉前 4 条）
      expect(out.first.content, 'u2');
      expect(out.last.content, 'a5');
    });

    test('truncateChatHistory: 默认 maxTurns=8 时 12 条 → 全留下', () {
      final history = <ChatTurn>[];
      for (var i = 0; i < 6; i++) {
        history.add(ChatTurn.user('u$i'));
        history.add(ChatTurn.assistant('a$i'));
      }
      final out = truncateChatHistory(history);
      expect(out.length, 12);
    });

    test('truncateChatHistory: 默认 maxTurns=8 时 20 条 → 留最近 16 条', () {
      final history = <ChatTurn>[];
      for (var i = 0; i < 10; i++) {
        history.add(ChatTurn.user('u$i'));
        history.add(ChatTurn.assistant('a$i'));
      }
      final out = truncateChatHistory(history);
      expect(out.length, 16);
      expect(out.first.content, 'u2');
      expect(out.last.content, 'a9');
    });
  });
}

/// 复制 AIService._parseJsonContent 的逻辑用于测试
Map<String, dynamic>? parseJsonForTest(String raw) {
  var content = raw.trim();

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
