# Bug 修复记录：AI API URL 拼接错误 & WebDAV 服务优化

## 修复日期

2026-06-05 ~ 2026-06-06

## 问题一：AI API 请求返回 404 / null 错误

### 现象

- "端点未找到：请检查 Base URL 和模型名称" (HTTP 404)
- "请求失败 (null): null" (连接/DNS 错误)

### 根因分析

**Bug 1**：`AIService` 使用 `_provider.baseUrl` 拼接 API URL，而 `_provider` 来自 `LLMProviderRegistry.getById(providerId)`。

当 `providerId = 'custom'` 时，预设的 `baseUrl` 为空字符串 `''`，导致 `fullApiUrl` 变为相对路径 `/v1/chat/completions`，Dio 无法正确解析。

**Bug 2**：GLM、千问、豆包 三个提供商的 `baseUrl` 已包含版本路径（如 `/v4`、`/v1`、`/v3`），但默认 `apiPath` 为 `/v1/chat/completions`，导致 URL 出现双版本路径错误：

- GLM: `.../api/paas/v4/v1/chat/completions` → 应为 `.../api/paas/v4/chat/completions`
- 千问: `.../compatible-mode/v1/v1/chat/completions` → 应为 `.../compatible-mode/v1/chat/completions`
- 豆包: `.../api/v3/v1/chat/completions` → 应为 `.../api/v3/chat/completions`

### 最终修复（V3 重构）

不再逐个修复 `baseUrl`/`apiPath`，而是彻底重构为 `apiUrl`（完整端点 URL）方案：

```dart
// 修复前（V1/V2）
String get fullApiUrl => '${_provider.baseUrl}${_provider.apiPath}';

// 修复后（V3）
String get fullApiUrl => config.apiUrl;  // 直接使用用户填写的完整 URL
```

预设提供商的 `apiUrl` 直接存完整地址（如 `https://api.openai.com/v1/chat/completions`），不再拆分。

## 问题二：response_format 不兼容

### 现象

部分厂商发送 `response_format: {"type": "json_object"}` 后返回 400 错误。

### 根因

并非所有 OpenAI 兼容厂商都支持 `response_format` 参数。之前通过 `supportsJsonMode` 字段区分，但自定义提供商无法预知是否支持。

### 最终修复

移除 `supportsJsonMode` 字段，统一不发送 `response_format`，改用 system prompt 强制要求 JSON 格式输出，并在解析时宽容处理。

## 问题三：模型名称硬编码过时

### 现象

硬编码的模型列表很快过时，如 DeepSeek 已从 `deepseek-chat` 更新到 `deepseek-v4-flash`。

### 最终修复

移除 `models` 预设列表，改为通过 `GET /models` 端点从厂商 API 动态获取。获取失败时返回空列表，用户手动输入模型名称。

**已知限制**：豆包（火山引擎 Ark）的数据面 API 不支持 `GET /models` 端点（返回 401），其模型列表需要通过管控面 API（HMAC-SHA256 鉴权）获取，当前不支持自动获取。

## 问题四：连接测试错误信息不友好

### 现象

之前的连接测试只返回"连接成功"或"连接失败"，无法帮助用户排查问题。

### 修复

新增 `testConnection()` 方法，返回 `ConnectionTestResult`（含 message + detail），针对不同错误码给出精确的中文提示和排查建议：

| 状态码 | 提示 | 排查建议 |
|--------|------|---------|
| 401 | API Key 无效或已过期 | 请检查 API Key 是否正确 |
| 403 | 访问被拒绝 | 请检查 API Key 权限 |
| 404 | 端点未找到 | 请检查 API URL 是否正确 |
| 400 | 请求参数错误 | 可能是模型名称不正确 |
| 429 | 连接正常（请求频率受限） | API Key 有效，请稍后再试 |
| 5xx | 厂商服务器错误 | 不是配置问题，请稍后再试 |
| 网络错误 | 无法连接到服务器 | 检查 URL/网络/代理 |

## 问题五：WebDAV 上传 404 错误（坚果云等服务）

### 现象

- 坚果云 WebDAV 上传返回 404 错误
- 请求 URL: `https://dav.jianguoyun.com/dav/catodo_tasks.json`

### 根因

坚果云等 WebDAV 服务不允许直接在根目录下创建文件，必须先创建子目录。

### 修复

1. 将任务文件名改为 `Catodo/catodo_tasks.json`（放在专门的目录下）
2. 新增 `_createDirectory` 方法，使用 WebDAV MKCOL 方法创建目录
3. `_uploadTasks` 方法在上传前先调用 `_createDirectory('/Catodo')` 确保目录存在
4. 目录创建对 405 状态码（目录已存在）视为成功

## 问题六：WebDAV 服务优化

**Bug 1**：Dio 的 `baseUrl` 相对路径解析在某些情况下行为不符合预期。

**修复**：新增 `buildUrl` 方法，手动拼接 URL：
- 自动去除 baseUrl 末尾斜杠
- 自动补全 path 前导斜杠
- 使用完整 URL 请求，避免 Dio 相对路径解析问题

**Bug 2**：`Accept: application/json` 头可能导致 WebDAV 服务器返回非预期响应。

**修复**：移除 `Accept: application/json` 头，仅在 PUT 上传时设置 `Content-Type: application/json`。

**Bug 3**：`testConnection` 的 PROPFIND 请求缺少 `Depth: 0` 头，部分服务器可能返回过多数据。

**修复**：添加 `Depth: 0` 头，仅请求根目录属性。

**Bug 4**：`_downloadTasks` 静默吞掉所有异常，首次同步和其他错误无法区分。

**修复**：区分 404（文件不存在，首次同步）和其他错误，增加日志输出。

## 测试结果

- **88/88 全部通过**
- 无编译错误
