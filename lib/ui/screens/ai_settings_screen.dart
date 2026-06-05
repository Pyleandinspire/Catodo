import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_service.dart';
import '../../services/llm_provider_registry.dart';

class AISettingsScreen extends ConsumerStatefulWidget {
  const AISettingsScreen({super.key});

  @override
  ConsumerState<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends ConsumerState<AISettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  String _selectedProviderId = 'custom';
  bool _isCustomProvider = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedProviderId = prefs.getString('ai_provider_id') ?? 'custom';
    _apiKeyController.text = prefs.getString('ai_api_key') ?? '';
    _baseUrlController.text = prefs.getString('ai_base_url') ?? '';
    _modelController.text = prefs.getString('ai_model') ?? '';

    _isCustomProvider = _selectedProviderId == 'custom';

    // 如果是预设提供商，自动填入默认值
    if (!_isCustomProvider) {
      final provider = LLMProviderRegistry.getById(_selectedProviderId);
      if (_baseUrlController.text.isEmpty) {
        _baseUrlController.text = provider.baseUrl;
      }
      if (_modelController.text.isEmpty) {
        _modelController.text = provider.defaultModel;
      }
    }

    setState(() {});
  }

  void _onProviderChanged(String? providerId) {
    if (providerId == null) return;
    setState(() {
      _selectedProviderId = providerId;
      _isCustomProvider = providerId == 'custom';
    });

    if (providerId != 'custom') {
      final provider = LLMProviderRegistry.getById(providerId);
      _baseUrlController.text = provider.baseUrl;
      _modelController.text = provider.defaultModel;
    }
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_provider_id', _selectedProviderId);
    await prefs.setString('ai_api_key', _apiKeyController.text.trim());
    await prefs.setString('ai_base_url', _baseUrlController.text.trim());
    await prefs.setString('ai_model', _modelController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 配置已保存'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);

    final config = AIConfig(
      providerId: _selectedProviderId,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      modelName: _modelController.text.trim(),
    );

    final service = AIService(config);
    final result = await service.requestStructuredOutput(
      systemPrompt: '你是一个测试助手。',
      userPrompt: '请回复 {"status": "ok"}',
    );

    setState(() => _isTesting = false);

    if (mounted) {
      final success = result != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '连接成功' : '连接失败，请检查配置'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProvider = LLMProviderRegistry.getById(_selectedProviderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手设置'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择模型提供商',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 提供商选择器
                    DropdownButtonFormField<String>(
                      value: _selectedProviderId,
                      decoration: const InputDecoration(
                        labelText: '模型提供商',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cloud),
                      ),
                      items: LLMProviderRegistry.providers.map((provider) {
                        return DropdownMenuItem(
                          value: provider.id,
                          child: Row(
                            children: [
                              _providerIcon(provider.id),
                              const SizedBox(width: 8),
                              Text(provider.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _onProviderChanged,
                    ),
                    const SizedBox(height: 12),

                    // 提供商描述
                    if (selectedProvider.description.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedProvider.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Base URL
                    TextField(
                      controller: _baseUrlController,
                      enabled: _isCustomProvider,
                      decoration: InputDecoration(
                        labelText: 'API Base URL',
                        hintText: 'https://api.openai.com',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.link),
                        filled: !_isCustomProvider,
                        fillColor: !_isCustomProvider
                            ? Colors.grey.shade100
                            : null,
                        suffixIcon: !_isCustomProvider
                            ? const Icon(
                                Icons.lock,
                                color: Colors.grey,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Model Name
                    if (_isCustomProvider)
                      TextField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model Name',
                          hintText: 'gpt-3.5-turbo',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.smart_toy),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value:
                            selectedProvider.models.contains(
                              _modelController.text,
                            )
                            ? _modelController.text
                            : selectedProvider.defaultModel,
                        decoration: const InputDecoration(
                          labelText: '模型',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.smart_toy),
                        ),
                        items: [
                          ...selectedProvider.models.map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          ),
                          const DropdownMenuItem(
                            value: '__custom__',
                            child: Text('自定义模型名称...'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == '__custom__') {
                            _showCustomModelDialog();
                          } else if (value != null) {
                            _modelController.text = value;
                          }
                        },
                      ),
                    const SizedBox(height: 12),

                    // API Key
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        hintText: _apiKeyHint(_selectedProviderId),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.key),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 操作按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isTesting ? null : _testConnection,
                            icon: _isTesting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.wifi_tethering),
                            label: Text(_isTesting ? '测试中...' : '测试连接'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _saveConfig,
                          child: const Text('保存配置'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 已支持的提供商列表
            const Text(
              '已支持的模型提供商',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            ...LLMProviderRegistry.providers
                .where((p) => p.id != 'custom')
                .map((provider) => _buildProviderCard(provider)),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.purple, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '所有预设提供商均兼容 OpenAI API 格式。\n'
                      '选择"自定义"可接入任意兼容 OpenAI 格式的 API 端点。\n'
                      '配置完成后可在聊天页面使用 AI 任务分解和情绪支持功能。',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(LLMProvider provider) {
    final isSelected = _selectedProviderId == provider.id;
    return Card(
      elevation: isSelected ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: isSelected ? 2 : 0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onProviderChanged(provider.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _providerIcon(provider.id),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      provider.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.blue, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _providerIcon(String providerId) {
    switch (providerId) {
      case 'deepseek':
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
        );
      case 'doubao':
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.green, size: 20),
        );
      case 'glm':
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
        );
      case 'qwen':
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
        );
      case 'moonshot':
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.indigo, size: 20),
        );
      case 'openai':
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.teal, size: 20),
        );
      default:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.settings, color: Colors.grey, size: 20),
        );
    }
  }

  String _apiKeyHint(String providerId) {
    switch (providerId) {
      case 'openai':
        return 'sk-...';
      case 'deepseek':
        return 'sk-...';
      case 'doubao':
        return '您的豆包 API Key';
      case 'glm':
        return '您的智谱 API Key';
      case 'qwen':
        return 'sk-...';
      case 'moonshot':
        return 'sk-...';
      default:
        return '输入 API Key';
    }
  }

  void _showCustomModelDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义模型名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入模型名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                _modelController.text = text;
                setState(() {});
              }
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
