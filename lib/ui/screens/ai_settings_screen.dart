import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_service.dart';
import '../../services/llm_provider_registry.dart';
import '../../services/secure_store.dart';

class AISettingsScreen extends ConsumerStatefulWidget {
  const AISettingsScreen({super.key});

  @override
  ConsumerState<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends ConsumerState<AISettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _modelController = TextEditingController();
  String _selectedProviderId = 'custom';
  bool _isCustomProvider = true;
  bool _isTesting = false;
  bool _isFetchingModels = false;
  bool _fetchModelsFailed = false;
  List<String> _fetchedModels = [];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedProviderId = prefs.getString('ai_provider_id') ?? 'custom';
    _apiKeyController.text =
        await SecureStore.instance.readAiApiKey() ?? '';
    _apiUrlController.text = prefs.getString('ai_api_url') ?? '';
    _modelController.text = prefs.getString('ai_model') ?? '';

    _isCustomProvider = _selectedProviderId == 'custom';

    // 如果是预设提供商，自动填入默认值
    if (!_isCustomProvider) {
      final provider = LLMProviderRegistry.getById(_selectedProviderId);
      if (_apiUrlController.text.isEmpty) {
        _apiUrlController.text = provider.apiUrl;
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
      _fetchedModels = [];
      _fetchModelsFailed = false;
    });

    if (providerId != 'custom') {
      final provider = LLMProviderRegistry.getById(providerId);
      _apiUrlController.text = provider.apiUrl;
      _modelController.text = provider.defaultModel;
    }
  }

  Future<void> _fetchModels() async {
    setState(() {
      _isFetchingModels = true;
      _fetchModelsFailed = false;
    });

    final config = AIConfig(
      providerId: _selectedProviderId,
      apiKey: _apiKeyController.text.trim(),
      apiUrl: _apiUrlController.text.trim(),
      modelName: _modelController.text.trim(),
    );

    final service = AIService(config);
    final models = await service.fetchModels();

    setState(() {
      _isFetchingModels = false;
      _fetchedModels = models;
      _fetchModelsFailed = models.isEmpty;
    });
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_provider_id', _selectedProviderId);
    await SecureStore.instance.writeAiApiKey(_apiKeyController.text.trim());
    await prefs.setString('ai_api_url', _apiUrlController.text.trim());
    await prefs.setString('ai_model', _modelController.text.trim());

    // 旧明文 key 若仍残留，主动清掉一次（双保险，迁移漏掉时兜底）
    await prefs.remove('ai_api_key');

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
      apiUrl: _apiUrlController.text.trim(),
      modelName: _modelController.text.trim(),
    );

    final service = AIService(config);
    final result = await service.testConnection();

    setState(() => _isTesting = false);

    if (mounted) {
      _showTestResultDialog(result);
    }
  }

  void _showTestResultDialog(ConnectionTestResult result) {
    final color = result.success ? Colors.green : Colors.red;
    final icon = result.success ? Icons.check_circle : Icons.error;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(icon, color: color, size: 48),
        title: Text(result.message),
        content: result.detail != null
            ? Text(
                result.detail!,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiUrlController.dispose();
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

                    // API URL
                    TextField(
                      controller: _apiUrlController,
                      decoration: InputDecoration(
                        labelText: 'API URL',
                        hintText: 'https://api.openai.com/v1/chat/completions',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Model Name - 动态获取 + 手动输入
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_fetchedModels.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value:
                                _fetchedModels.contains(_modelController.text)
                                ? _modelController.text
                                : null,
                            decoration: const InputDecoration(
                              labelText: '模型',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.smart_toy),
                            ),
                            items: [
                              ..._fetchedModels.map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              ),
                              const DropdownMenuItem(
                                value: '__custom__',
                                child: Text('手动输入模型名称...'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == '__custom__') {
                                _showCustomModelDialog();
                              } else if (value != null) {
                                _modelController.text = value;
                              }
                            },
                          )
                        else
                          TextField(
                            controller: _modelController,
                            decoration: InputDecoration(
                              labelText: '模型名称',
                              hintText: _isCustomProvider
                                  ? 'gpt-3.5-turbo'
                                  : selectedProvider.defaultModel,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.smart_toy),
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isFetchingModels ? null : _fetchModels,
                            icon: _isFetchingModels
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh, size: 16),
                            label: Text(
                              _isFetchingModels
                                  ? '获取中...'
                                  : _fetchedModels.isNotEmpty
                                  ? '刷新模型列表'
                                  : '从 API 获取模型列表',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        if (_fetchModelsFailed)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '获取失败，请检查 API URL 和 API Key，或手动输入模型名称',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
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
                      '选择提供商后自动填入 API URL，也可手动修改。\n'
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
