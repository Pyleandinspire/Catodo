# 阶段六：多模型API支持开发

## 开发目标
1. 实现多模型提供商注册表（预设配置）
2. 改造 AI 服务层支持智能适配
3. 改造 AI 设置界面（提供商选择器 + 自定义）
4. 支持国产大模型：DeepSeek、豆包、GLM、千问、Kimi 等
5. 动态获取厂商可用模型列表（取代硬编码模型名）

## 技术方案：预设配置 + 动态模型 + 最大兼容性

### 方案概述
- 保持现有 OpenAI 兼容的 API 调用架构
- 为每个主流大模型提供商预设完整 API URL、默认模型列表
- 用户选择提供商后自动填入配置，减少手动输入
- 保留"自定义"选项，支持任意 OpenAI 兼容端点
- **动态模型列表**：通过 `GET /models` 端点从厂商 API 获取当前可用模型
- **最大兼容性策略**：不发送 `response_format`，宽容解析响应和 JSON

### 预设提供商

| 提供商 | API URL | 默认模型 | 认证方式 |
|--------|---------|---------|----------|
| OpenAI | https://api.openai.com/v1/chat/completions | gpt-3.5-turbo | Bearer Token |
| DeepSeek | https://api.deepseek.com/v1/chat/completions | deepseek-chat | Bearer Token |
| 豆包 (Doubao) | https://ark.cn-beijing.volces.com/api/v3/chat/completions | doubao-pro-32k | Bearer Token |
| 智谱 GLM | https://open.bigmodel.cn/api/paas/v4/chat/completions | glm-4-flash | Bearer Token |
| 通义千问 (Qwen) | https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions | qwen-turbo | Bearer Token |
| Moonshot (Kimi) | https://api.moonshot.cn/v1/chat/completions | moonshot-v1-8k | Bearer Token |
| 自定义 | 用户输入 | 用户输入 | Bearer Token |

### 动态模型列表技术方案

**原理**：所有 OpenAI 兼容厂商都支持 `GET /models` 端点，返回格式统一：
```json
{
  "object": "list",
  "data": [
    {"id": "gpt-4o", "object": "model", "owned_by": "openai"},
    {"id": "gpt-3.5-turbo", "object": "model", "owned_by": "openai"}
  ]
}
```

**URL 推导**：从用户填写的 `apiUrl` 推导出 models 端点：
- `https://api.openai.com/v1/chat/completions` → `https://api.openai.com/v1/models`
- `https://open.bigmodel.cn/api/paas/v4/chat/completions` → `https://open.bigmodel.cn/api/paas/v4/models`
- 规则：将 `/chat/completions` 替换为 `/models`

**降级策略**：如果 `GET /models` 请求失败，显示预设模型列表作为 fallback

## 具体任务

### 6.1 创建提供商注册表
- 创建 `lib/services/llm_provider_registry.dart`
- 定义 `LLMProvider` 数据类（name, apiUrl, defaultModel, models, description）
- 预置所有支持的提供商配置
- 移除 `supportsJsonMode` 字段（不再需要，统一用 prompt 强制 JSON）

### 6.2 改造 AI 服务层
- 修改 `AIConfig`：`baseUrl` → `apiUrl`（完整端点 URL）
- 修改 `AIService`：
  - `fullApiUrl` 直接返回 `config.apiUrl`，不再拼接
  - 不发送 `response_format` 参数（最大兼容性）
  - 宽容解析响应：兼容 `choices[0].message.content`、`output.text`、`data` 等格式
  - 宽容解析 JSON：兼容 markdown 代码块包裹、多余文字
  - 新增 `testConnection()` 方法：返回 `ConnectionTestResult`（含详细错误信息）
  - 新增 `fetchModels()` 方法：从厂商 API 动态获取模型列表

### 6.3 改造 AI 设置界面
- 增加提供商选择器（下拉列表）
- 选择提供商后自动填入 API URL 和推荐模型
- **模型选择改为动态获取**：
  - 点击"获取模型列表"按钮 → 调用 `fetchModels()` → 显示下拉选择
  - 获取失败时显示预设模型列表（fallback）
  - 保留手动输入模型名称的能力
- 保留自定义选项，支持手动输入所有参数
- 连接测试改为使用 `testConnection()`，展示详细错误信息和排查建议

### 6.4 配置持久化
- 在 shared_preferences 中增加 `ai_provider_id` 字段
- 存储键从 `ai_base_url` 改为 `ai_api_url`
- 选择预设提供商时，自动保存 API URL 和 Model
- 切换提供商时，清除旧的 API Key（安全性考虑）

## 测试标准

### 6.1 提供商预设测试
- [x] 选择 DeepSeek 后自动填入正确的 API URL
- [x] 选择 GLM 后自动填入正确的 API URL
- [x] 选择千问后自动填入正确的 API URL
- [x] 选择豆包后自动填入正确的 API URL
- [x] 选择 Kimi 后自动填入正确的 API URL
- [x] 选择自定义后所有字段可手动编辑

### 6.2 兼容性测试
- [x] 不发送 response_format，所有厂商都能正常响应
- [x] 宽容解析 JSON（markdown 代码块、多余文字）
- [x] 宽容解析响应（非标准格式）
- [x] 连接测试返回详细错误信息

### 6.3 动态模型列表测试
- [ ] fetchModels() 正确推导 models 端点 URL
- [ ] fetchModels() 正确解析返回的模型列表
- [ ] fetchModels() 请求失败时返回预设模型列表
- [ ] UI 正确展示动态获取的模型列表
- [ ] 手动输入模型名称仍然可用

### 6.4 配置持久化测试
- [x] 选择提供商后配置正确保存
- [x] 重启应用后配置正确恢复
- [x] 切换提供商后配置正确更新

## 依赖

无需新增依赖，复用现有：
- `dio`：HTTP 请求
- `shared_preferences`：配置持久化