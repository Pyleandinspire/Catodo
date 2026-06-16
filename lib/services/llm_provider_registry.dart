class LLMProvider {
  final String id;
  final String name;
  final String apiUrl;
  final String defaultModel;
  final String description;
  final double defaultTemperature;

  const LLMProvider({
    required this.id,
    required this.name,
    required this.apiUrl,
    required this.defaultModel,
    this.description = '',
    this.defaultTemperature = 0.3,
  });
}

class LLMProviderRegistry {
  static const List<LLMProvider> providers = [
    LLMProvider(
      id: 'openai',
      name: 'OpenAI',
      apiUrl: 'https://api.openai.com/v1/chat/completions',
      defaultModel: 'gpt-3.5-turbo',
      description: 'OpenAI 官方模型，综合能力强',
      defaultTemperature: 0.3,
    ),
    LLMProvider(
      id: 'deepseek',
      name: 'DeepSeek',
      apiUrl: 'https://api.deepseek.com/v1/chat/completions',
      defaultModel: 'deepseek-chat',
      description: '深度求索，性价比极高，中文能力强',
      defaultTemperature: 0.3,
    ),
    LLMProvider(
      id: 'doubao',
      name: '豆包 ByteDance',
      apiUrl: 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
      defaultModel: 'doubao-pro-32k',
      description: '字节跳动豆包大模型，支持超长上下文',
      defaultTemperature: 0.3,
    ),
    LLMProvider(
      id: 'glm',
      name: '智谱 GLM',
      apiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      defaultModel: 'glm-4-flash',
      description: '智谱 AI，GLM 系列模型',
      defaultTemperature: 0.3,
    ),
    LLMProvider(
      id: 'qwen',
      name: '通义千问 Qwen',
      apiUrl:
          'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
      defaultModel: 'qwen-turbo',
      description: '阿里通义千问，多模态能力强',
      defaultTemperature: 0.3,
    ),
    LLMProvider(
      id: 'moonshot',
      name: 'Moonshot Kimi',
      apiUrl: 'https://api.moonshot.cn/v1/chat/completions',
      defaultModel: 'moonshot-v1-8k',
      description: '月之暗面 Kimi，超长上下文',
      defaultTemperature: 0.3,
    ),
    LLMProvider(
      id: 'custom',
      name: '自定义',
      apiUrl: '',
      defaultModel: '',
      description: '输入任意兼容 OpenAI 格式的 API 端点',
      defaultTemperature: 0.3,
    ),
  ];

  static LLMProvider getById(String id) {
    return providers.firstWhere(
      (p) => p.id == id,
      orElse: () => providers.last,
    );
  }

  static LLMProvider getByApiUrl(String apiUrl) {
    for (final provider in providers) {
      if (provider.id != 'custom' && apiUrl.startsWith(provider.apiUrl)) {
        return provider;
      }
    }
    return providers.last;
  }
}
