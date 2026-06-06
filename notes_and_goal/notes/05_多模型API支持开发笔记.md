# 阶段六开发笔记：多模型API支持

## 一、开发概述

为 Catodo 增加国产大模型 API 支持，包括 DeepSeek、豆包（Doubao）、智谱 GLM、通义千问（Qwen）、Moonshot（Kimi）等，同时保留 OpenAI 和自定义端点。

经历了三个版本的架构演进，最终形成"最大兼容性 + 动态模型列表"的方案。

## 二、架构演进

### V1：baseUrl + apiPath 拆分 + supportsJsonMode

```dart
class LLMProvider {
  final String baseUrl;       // 如 https://api.openai.com
  final String apiPath;       // 如 /v1/chat/completions
  final bool supportsJsonMode; // 是否支持 response_format
}
```

**问题**：
- 双版本路径：GLM/千问/豆包的 baseUrl 已含版本路径，拼接后出现 `/v4/v1/chat/completions`
- `supportsJsonMode` 区分导致代码分支多，且自定义提供商默认值不好设
- 用户需要理解 baseUrl 和 apiPath 的区别，门槛高

### V2：修复双版本路径（Bug 修复阶段）

为 GLM/千问/豆包单独设 `apiPath: '/chat/completions'`，其他用 `/v1/chat/completions`。

**问题**：治标不治本，每新增一个厂商都要判断路径格式。

### V3：apiUrl 完整端点 URL + 最大兼容性（当前最终方案）

```dart
class LLMProvider {
  final String id;
  final String name;
  final String apiUrl;           // 完整端点 URL
  final String defaultModel;     // 仅作默认值，不硬编码模型列表
  final String description;
  final double defaultTemperature;
}
```

**核心改动**：
- `baseUrl + apiPath` → `apiUrl`（完整 URL，如 `https://api.openai.com/v1/chat/completions`）
- 移除 `supportsJsonMode`，统一不发送 `response_format`，改用 prompt 强制 JSON
- 移除 `models` 预设列表，改为从 `GET /models` 端点动态获取
- 新增 `testConnection()` 返回详细错误信息
- 新增 `fetchModels()` 动态获取模型列表

## 三、最终技术方案

### 3.1 最大兼容性策略

| 策略 | 说明 |
|------|------|
| 不发送 `response_format` | 部分厂商不支持会报 400，改用 prompt 强制 JSON |
| 宽容解析响应 | 兼容 `choices[0].message.content`、`output.text`、`data` 等 |
| 宽容解析 JSON | 兼容 markdown 代码块包裹、多余文字、空白换行 |
| 动态模型列表 | 通过 `GET /models` 获取，失败返回空列表 |
| 完整 URL | 用户直接填厂商给的完整 API URL，不做拼接 |

### 3.2 动态模型列表

**原理**：OpenAI 兼容厂商都支持 `GET /models` 端点，返回格式统一：
```json
{
  "data": [
    {"id": "gpt-4o", "object": "model"},
    {"id": "gpt-3.5-turbo", "object": "model"}
  ]
}
```

**URL 推导**：从 `apiUrl` 替换 `/chat/completions` → `/models`

**已知限制**：豆包（火山引擎 Ark）的数据面 API 不支持 `GET /models`，获取失败时返回空列表，用户需手动输入模型名称。

### 3.3 连接测试

`testConnection()` 返回 `ConnectionTestResult`，包含：
- `success`：是否成功
- `message`：简短结果描述
- `detail`：详细排查建议

针对 401/403/404/400/429/5xx/网络错误分别给出精确的中文提示和排查建议。

## 四、预设提供商

| 提供商 | ID | API URL | 默认模型 |
|--------|-----|---------|---------|
| OpenAI | openai | https://api.openai.com/v1/chat/completions | gpt-3.5-turbo |
| DeepSeek | deepseek | https://api.deepseek.com/v1/chat/completions | deepseek-chat |
| 豆包 | doubao | https://ark.cn-beijing.volces.com/api/v3/chat/completions | doubao-pro-32k |
| 智谱 GLM | glm | https://open.bigmodel.cn/api/paas/v4/chat/completions | glm-4-flash |
| 通义千问 | qwen | https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions | qwen-turbo |
| Moonshot | moonshot | https://api.moonshot.cn/v1/chat/completions | moonshot-v1-8k |
| 自定义 | custom | 用户输入 | 用户输入 |

## 五、新增/修改文件

### 5.1 `lib/services/llm_provider_registry.dart`

- `LLMProvider` 数据类：id, name, apiUrl, defaultModel, description, defaultTemperature
- `LLMProviderRegistry`：7 个预设提供商 + getById/getByApiUrl 查询

### 5.2 `lib/services/ai_service.dart`

- `AIConfig`：providerId, apiKey, apiUrl, modelName
- `ConnectionTestResult`：success, message, detail
- `AIService`：
  - `fullApiUrl`：直接返回 `config.apiUrl`
  - `modelsEndpoint`：从 apiUrl 推导 models 端点
  - `fetchModels()`：动态获取模型列表，失败返回空列表
  - `testConnection()`：轻量级连接测试，返回详细结果
  - `requestStructuredOutput()`：请求结构化 JSON 输出（最大兼容性）
  - `_extractContent()`：宽容解析响应内容
  - `_parseJsonContent()`：宽容解析 JSON

### 5.3 `lib/ui/screens/ai_settings_screen.dart`

- 提供商选择器 + 自动填充
- 模型名称：手动输入 + "从 API 获取模型列表"按钮
- 获取成功切换为下拉选择，获取失败显示红色提示
- 连接测试：使用 `testConnection()`，弹窗展示详细结果

### 5.4 `lib/ui/screens/chat_screen.dart`

- 适配 `apiUrl` 字段名和 `ai_api_url` 存储键

## 六、测试结果

- **88/88 单元测试全部通过**
- 覆盖：6 个提供商 URL、配置有效性、JSON 宽容解析、连接测试结果、modelsEndpoint 推导

## 七、后续扩展

如需添加新的大模型提供商，只需在 `LLMProviderRegistry.providers` 列表中添加一个 `LLMProvider` 实例即可，无需修改其他代码。
