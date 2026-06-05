# Bug 修复记录：AI API URL 拼接错误 & WebDAV 服务优化

## 修复日期

2026-06-05

## 问题一：AI API 请求返回 404 / null 错误

### 现象

- "端点未找到：请检查 Base URL 和模型名称" (HTTP 404)
- "请求失败 (null): null" (连接/DNS 错误)

### 根因分析

**Bug 1**：`AIService` 使用 `_provider.baseUrl` 拼接 API URL，而 `_provider` 来自 `LLMProviderRegistry.getById(providerId)`。

当 `providerId = 'custom'` 时，预设的 `baseUrl` 为空字符串 `''`，导致 `fullApiUrl` 变为相对路径 `/v1/chat/completions`，Dio 无法正确解析。

**修复**：改用 `config.baseUrl`（用户实际输入的 Base URL）拼接 API 路径：

```dart
// 修复前
String get fullApiUrl => '${_provider.baseUrl}${_provider.apiPath}';

// 修复后
String get fullApiUrl => '${config.baseUrl}${_provider.apiPath}';
```

**Bug 2**：GLM、千问、豆包 三个提供商的 `baseUrl` 已包含版本路径（如 `/v4`、`/v1`、`/v3`），但默认 `apiPath` 为 `/v1/chat/completions`，导致 URL 出现双版本路径错误：

- GLM: `.../api/paas/v4/v1/chat/completions` → 应为 `.../api/paas/v4/chat/completions`
- 千问: `.../compatible-mode/v1/v1/chat/completions` → 应为 `.../compatible-mode/v1/chat/completions`
- 豆包: `.../api/v3/v1/chat/completions` → 应为 `.../api/v3/chat/completions`

**修复**：为这三个提供商显式设置 `apiPath: '/chat/completions'`。

### 其他改进

- 请求头改为在 `BaseOptions` 构造函数中直接设置，避免 Dio 内部覆盖
- 错误信息增加请求 URL 打印，便于调试
- 错误处理增加 `e.type.name` 作为 fallback

## 问题三：WebDAV 上传 404 错误（坚果云等服务）

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

### 改动文件

- `lib/services/webdav_service.dart`
  - 修改 `_tasksFileName` 为 `Catodo/catodo_tasks.json`
  - 新增 `_createDirectory` 方法
  - `_uploadTasks` 方法调用 `_createDirectory`

## 问题二：WebDAV 服务优化

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

## 新增测试

### ai_service_test.dart (13 个用例)

- 6 个提供商的 URL 拼接测试
- 自定义提供商 URL 测试
- 默认 providerId 测试
- 配置有效性测试
- 提供商注册表测试

### webdav_service_test.dart (10 个用例)

- URL 拼接测试（带/不带斜杠等边界情况）
- 配置有效性测试
- SyncResult 测试

## 测试结果

- **52/52 全部通过**
- 无编译错误
