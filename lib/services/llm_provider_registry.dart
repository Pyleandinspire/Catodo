class LLMProvider {
  final String id;
  final String name;
  final String baseUrl;
  final String defaultModel;
  final List<String> models;
  final String description;
  final String apiPath;
  final double defaultTemperature;
  final bool supportsJsonMode;

  const LLMProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    this.models = const [],
    this.description = '',
    this.apiPath = '/v1/chat/completions',
    this.defaultTemperature = 0.3,
    this.supportsJsonMode = true,
  });
}

class LLMProviderRegistry {
  static const List<LLMProvider> providers = [
    LLMProvider(
      id: 'openai',
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com',
      defaultModel: 'gpt-3.5-turbo',
      models: [
        'gpt-3.5-turbo',
        'gpt-4o',
        'gpt-4o-mini',
        'gpt-4-turbo',
        'gpt-4',
      ],
      description: 'OpenAI 官方模型，综合能力强',
      defaultTemperature: 0.3,
      supportsJsonMode: true,
    ),
    LLMProvider(
      id: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      defaultModel: 'deepseek-chat',
      models: ['deepseek-chat', 'deepseek-reasoner'],
      description: '深度求索，性价比极高，中文能力强',
      defaultTemperature: 0.3,
      supportsJsonMode: true,
    ),
    LLMProvider(
      id: 'doubao',
      name: '豆包 (ByteDance)',
      baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
      defaultModel: 'doubao-pro-32k',
      models: [
        'doubao-pro-32k',
        'doubao-pro-128k',
        'doubao-lite-32k',
        'doubao-lite-128k',
      ],
      description: '字节跳动豆包大模型，支持超长上下文',
      defaultTemperature: 0.3,
      supportsJsonMode: true,
      apiPath: '/chat/completions',
    ),
    LLMProvider(
      id: 'glm',
      name: '智谱 GLM',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      defaultModel: 'glm-4-flash',
      models: [
        'glm-4-flash',
        'glm-4',
        'glm-4-plus',
        'glm-4-air',
        'glm-4-long',
      ],
      description: '智谱 AI，GLM 系列模型',
      defaultTemperature: 0.3,
      supportsJsonMode: true,
      apiPath: '/chat/completions',
    ),
    LLMProvider(
      id: 'qwen',
      name: '通义千问 (Qwen)',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      defaultModel: 'qwen-turbo',
      models: [
        'qwen-turbo',
        'qwen-plus',
        'qwen-max',
        'qwen-max-longcontext',
      ],
      description: '阿里通义千问，多模态能力强',
      defaultTemperature: 0.3,
      supportsJsonMode: true,
      apiPath: '/chat/completions',
    ),
    LLMProvider(
      id: 'moonshot',
      name: 'Moonshot (Kimi)',
      baseUrl: 'https://api.moonshot.cn',
      defaultModel: 'moonshot-v1-8k',
      models: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'],
      description: '月之暗面 Kimi，超长上下文',
      defaultTemperature: 0.3,
      supportsJsonMode: true,
    ),
    LLMProvider(
      id: 'custom',
      name: '自定义',
      baseUrl: '',
      defaultModel: '',
      models: [],
      description: '输入任意兼容 OpenAI 格式的 API 端点',
      defaultTemperature: 0.3,
      supportsJsonMode: true,
    ),
  ];

  static LLMProvider getById(String id) {
    return providers.firstWhere(
      (p) => p.id == id,
      orElse: () => providers.last, // 默认返回自定义
    );
  }

  static LLMProvider getByBaseUrl(String baseUrl) {
    // 尝试根据 baseUrl 匹配已知提供商
    for (final provider in providers) {
      if (provider.id != 'custom' && baseUrl.startsWith(provider.baseUrl)) {
        return provider;
      }
    }
    return providers.last; // 自定义
  }
}
