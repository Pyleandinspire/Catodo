import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/services/ai_service.dart';
import 'package:catodo/services/llm_provider_registry.dart';

void main() {
  group('AIConfig URL 构建测试', () {
    test('预设提供商 - DeepSeek URL 正确拼接', () {
      final config = AIConfig(
        providerId: 'deepseek',
        apiKey: 'sk-test',
        baseUrl: 'https://api.deepseek.com',
        modelName: 'deepseek-chat',
      );
      final service = AIService(config);
      expect(
        service.fullApiUrl,
        'https://api.deepseek.com/v1/chat/completions',
      );
    });

    test('预设提供商 - OpenAI URL 正确拼接', () {
      final config = AIConfig(
        providerId: 'openai',
        apiKey: 'sk-test',
        baseUrl: 'https://api.openai.com',
        modelName: 'gpt-3.5-turbo',
      );
      final service = AIService(config);
      expect(service.fullApiUrl, 'https://api.openai.com/v1/chat/completions');
    });

    test('预设提供商 - 智谱 GLM URL 正确拼接', () {
      final config = AIConfig(
        providerId: 'glm',
        apiKey: 'test-key',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        modelName: 'glm-4-flash',
      );
      final service = AIService(config);
      expect(
        service.fullApiUrl,
        'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      );
    });

    test('预设提供商 - 千问 URL 正确拼接', () {
      final config = AIConfig(
        providerId: 'qwen',
        apiKey: 'sk-test',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        modelName: 'qwen-turbo',
      );
      final service = AIService(config);
      expect(
        service.fullApiUrl,
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
      );
    });

    test('预设提供商 - 豆包 URL 正确拼接', () {
      final config = AIConfig(
        providerId: 'doubao',
        apiKey: 'test-key',
        baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
        modelName: 'doubao-pro-32k',
      );
      final service = AIService(config);
      expect(
        service.fullApiUrl,
        'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
      );
    });

    test('预设提供商 - Kimi URL 正确拼接', () {
      final config = AIConfig(
        providerId: 'moonshot',
        apiKey: 'sk-test',
        baseUrl: 'https://api.moonshot.cn',
        modelName: 'moonshot-v1-8k',
      );
      final service = AIService(config);
      expect(service.fullApiUrl, 'https://api.moonshot.cn/v1/chat/completions');
    });

    test('自定义提供商 - 使用用户输入的 baseUrl', () {
      final config = AIConfig(
        providerId: 'custom',
        apiKey: 'sk-test',
        baseUrl: 'https://my-custom-api.example.com',
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
        baseUrl: 'https://test.com',
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
        baseUrl: 'https://test.com',
        modelName: 'test-model',
      );
      expect(config.isValid, true);
    });

    test('缺少 apiKey 无效', () {
      final config = AIConfig(
        apiKey: '',
        baseUrl: 'https://test.com',
        modelName: 'test-model',
      );
      expect(config.isValid, false);
    });
  });

  group('LLMProviderRegistry 测试', () {
    test('getById 返回正确的提供商', () {
      final provider = LLMProviderRegistry.getById('deepseek');
      expect(provider.name, 'DeepSeek');
      expect(provider.baseUrl, 'https://api.deepseek.com');
    });

    test('未知 id 返回自定义', () {
      final provider = LLMProviderRegistry.getById('unknown');
      expect(provider.id, 'custom');
    });

    test('所有预设提供商都有有效的 baseUrl', () {
      for (final provider in LLMProviderRegistry.providers) {
        if (provider.id != 'custom') {
          expect(
            provider.baseUrl.isNotEmpty,
            true,
            reason: '${provider.name} 的 baseUrl 不应为空',
          );
          expect(
            provider.baseUrl.startsWith('https://'),
            true,
            reason: '${provider.name} 的 baseUrl 应以 https:// 开头',
          );
        }
      }
    });
  });
}
