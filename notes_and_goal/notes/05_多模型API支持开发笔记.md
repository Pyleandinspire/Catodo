# 阶段六开发笔记：多模型API支持

## 一、开发概述

按 `06_多模型API支持开发.md` 流程，为 Catodo 增加了国产大模型 API 支持，包括 DeepSeek、豆包（Doubao）、智谱 GLM、通义千问（Qwen）、Moonshot（Kimi）等，同时保留 OpenAI 和自定义端点。

## 二、技术方案：预设配置 + 智能适配

选择理由：
- 国产大模型基本都兼容 OpenAI API 格式，无需多适配器抽象
- 预设配置降低用户使用门槛（无需手动查 Base URL）
- 智能适配处理不同提供商的参数差异

## 三、新增/修改文件

### 3.1 新增：`lib/services/llm_provider_registry.dart`

提供商注册表，包含 7 个提供商预设：

| 提供商 | ID | 默认模型 | 特性 |
|--------|-----|---------|------|
| OpenAI | openai | gpt-3.5-turbo | 5 个模型可选 |
| DeepSeek | deepseek | deepseek-chat | 高性价比，中文强 |
| 豆包 | doubao | doubao-pro-32k | 超长上下文 |
| 智谱 GLM | glm | glm-4-flash | 5 个模型可选 |
| 通义千问 | qwen | qwen-turbo | 4 个模型可选 |
| Kimi | moonshot | moonshot-v1-8k | 超长上下文 |
| 自定义 | custom | - | 任意 OpenAI 兼容端点 |

每个提供商配置了：
- `baseUrl`：API 端点地址
- `apiPath`：API 路径（默认 `/v1/chat/completions`）
- `defaultTemperature`：默认温度参数
- `supportsJsonMode`：是否支持 JSON 模式（不支持时自动在 prompt 中强调 JSON 格式）

### 3.2 修改：`lib/services/ai_service.dart`

- `AIConfig` 新增 `providerId` 字段，关联到 `LLMProvider`
- `AIService` 不再硬编码请求路径，而是通过 `config.baseUrl + _provider.apiPath` 动态拼接
- 各提供商使用不同的 `apiPath`：OpenAI/DeepSeek/Kimi 使用 `/v1/chat/completions`，GLM/千问/豆包使用 `/chat/completions`（baseUrl 已包含版本路径）
- 根据 `supportsJsonMode` 自动适配请求参数
- 新增 `_parseError` 方法，提供友好的 HTTP 错误提示

### 3.3 修改：`lib/ui/screens/ai_settings_screen.dart`

完全重写，新增功能：
- **提供商选择器**：下拉列表选择预设提供商
- **自动填充**：选择后自动填入 Base URL 和默认模型
- **模型下拉选择**：预设提供商显示模型列表下拉选择
- **自定义模型名称**：支持输入任意模型名称
- **提供商描述**：显示当前选中提供商的简介
- **提供商卡片列表**：底部展示所有支持的提供商，选中高亮
- **锁定非自定义字段**：选择预设提供商后 Base URL 只读

### 3.4 修改：`lib/ui/screens/chat_screen.dart`

- `_initAIService` 方法增加 `providerId` 读取和传递

## 四、智能适配机制

### 4.1 JSON 模式适配
不同提供商的 JSON 模式支持情况不同：
- 支持 `response_format`：直接添加 `{"type": "json_object"}`
- 不支持：在 system prompt 末尾追加 JSON 格式强调指令

### 4.2 参数适配
- `temperature`：使用提供商预设值（默认 0.3）
- `connectTimeout`：15 秒
- `receiveTimeout`：60 秒

### 4.3 错误处理
HTTP 状态码对应中文提示：
- 401 → 认证失败
- 403 → 访问被拒绝
- 404 → 端点未找到
- 429 → 请求频率超限
- 500 → 服务器内部错误
- 503 → 服务暂时不可用

## 五、测试结果

- **28/28 单元测试全部通过**
- **静态分析无编译错误**（仅有 info/warning 级别提示，均为已存在的代码风格问题）

## 六、后续扩展

如需添加新的大模型提供商，只需在 `LLMProviderRegistry.providers` 列表中添加一个 `LLMProvider` 实例即可，无需修改其他代码。