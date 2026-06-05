# 阶段六：多模型API支持开发

## 开发目标
1. 实现多模型提供商注册表（预设配置）
2. 改造 AI 服务层支持智能适配
3. 改造 AI 设置界面（提供商选择器 + 自定义）
4. 支持国产大模型：DeepSeek、豆包、GLM、千问、Kimi 等

## 技术方案：预设配置 + 智能适配

### 方案概述
- 保持现有 OpenAI 兼容的 API 调用架构
- 为每个主流大模型提供商预设 Base URL、默认模型列表
- 用户选择提供商后自动填入配置，减少手动输入
- 保留"自定义"选项，支持任意 OpenAI 兼容端点
- 增加请求参数智能适配（如不同提供商的默认参数调整）

### 预设提供商

| 提供商 | Base URL | 默认模型 | 认证方式 |
|--------|----------|---------|----------|
| OpenAI | https://api.openai.com | gpt-3.5-turbo | Bearer Token |
| DeepSeek | https://api.deepseek.com | deepseek-chat | Bearer Token |
| 豆包 (Doubao) | https://ark.cn-beijing.volces.com/api/v3 | doubao-pro-32k | Bearer Token |
| 智谱 GLM | https://open.bigmodel.cn/api/paas/v4 | glm-4-flash | Bearer Token |
| 通义千问 (Qwen) | https://dashscope.aliyuncs.com/compatible-mode/v1 | qwen-turbo | Bearer Token |
| Moonshot (Kimi) | https://api.moonshot.cn | moonshot-v1-8k | Bearer Token |
| 自定义 | 用户输入 | 用户输入 | Bearer Token |

## 具体任务

### 6.1 创建提供商注册表
- 创建 `lib/services/llm_provider_registry.dart`
- 定义 `LLMProvider` 数据类（name, baseUrl, defaultModel, models, description）
- 预置所有支持的提供商配置

### 6.2 改造 AI 服务层
- 修改 `AIConfig`：增加 `providerId` 字段
- 修改 `AIService`：
  - 请求路径动态拼接（不再硬编码 `/v1/chat/completions`）
  - 根据提供商自动调整默认参数（temperature, top_p 等）
  - 请求失败时提供更友好的错误提示

### 6.3 改造 AI 设置界面
- 增加提供商选择器（下拉列表）
- 选择提供商后自动填入 Base URL 和推荐模型
- 模型输入框改为下拉选择 + 自定义输入
- 保留自定义选项，支持手动输入所有参数
- 显示选中提供商的描述信息

### 6.4 配置持久化
- 在 shared_preferences 中增加 `ai_provider_id` 字段
- 选择预设提供商时，自动保存 Base URL 和 Model
- 切换提供商时，清除旧的 API Key（安全性考虑）

## 测试标准

### 6.1 提供商预设测试
- [ ] 选择 DeepSeek 后自动填入正确的 Base URL
- [ ] 选择 GLM 后自动填入正确的 Base URL
- [ ] 选择千问后自动填入正确的 Base URL
- [ ] 选择豆包后自动填入正确的 Base URL
- [ ] 选择 Kimi 后自动填入正确的 Base URL
- [ ] 选择自定义后所有字段可手动编辑

### 6.2 智能适配测试
- [ ] 不同提供商的请求参数正确适配
- [ ] 连接测试使用对应提供商的 API 格式
- [ ] 错误信息友好显示

### 6.3 配置持久化测试
- [ ] 选择提供商后配置正确保存
- [ ] 重启应用后配置正确恢复
- [ ] 切换提供商后配置正确更新

## 依赖

无需新增依赖，复用现有：
- `dio`：HTTP 请求
- `shared_preferences`：配置持久化