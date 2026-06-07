[English](README.md) | **[中文](README.zh-CN.md)** | [日本語](README.ja.md) | [Deutsch](README.de.md)

---

# Catodo

基于 Flutter 构建的跨平台待办事项管理应用。通过智能视图、AI 助手和 WebDAV 无缝跨设备同步，轻松管理你的待办事项。

## 功能特性

- **任务管理** - 创建、编辑、完成和删除任务，支持优先级、标签、分组、截止日期和多个提醒
- **智能视图** - 列表视图、按天视图（专注今日 / 隐藏过期）和艾森豪威尔矩阵，按优先级组织任务
- **重复任务** - 设置每天、每周或每月的重复规则；完成时自动生成下一个实例
- **WebDAV 同步** - 增量式跨设备同步，支持三种冲突解决模式（自动合并、本地优先、远程优先）和软删除传播
- **AI 助手** - 通过自然语言与 LLM Agent 对话，创建、更新、分解和管理任务
- **数据导入导出** - 支持 `.ics` 日历格式和 `.catodo` 完整备份格式（可选包含敏感设置）
- **本地通知** - 定时提醒，应用重启后自动重新调度
- **多平台** - Android、iOS、Windows、macOS、Linux 和 Web

## 安装

### 前置条件

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.12.0
- Dart SDK >= 3.12.0
- Android：Android SDK，minSdkVersion 21+
- iOS：Xcode 15+、CocoaPods
- 桌面端：对应平台的构建工具

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/your-username/catodo.git
cd catodo

# 安装依赖
flutter pub get

# 生成 Isar 数据模型
dart run build_runner build --delete-conflicting-outputs

# 在已连接的设备或模拟器上运行
flutter run
```

### 构建发布版本

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release

# Web
flutter build web --release
```

## 使用说明

### 任务管理

| 操作 | 方法 |
|------|------|
| 创建任务 | 点击底部栏的 **+** 按钮，填写表单，点击 **保存** |
| 编辑任务 | 点击任务卡片打开编辑器 |
| 完成任务 | 点击任务卡片上的圆形勾选框 |
| 删除任务 | 打开任务编辑器，滚动到底部，点击 **删除任务**，确认操作 |
| 设置优先级 | 在任务表单中选择 无 / 低 / 中 / 高 |
| 设置提醒 | 在任务表单中点击 **添加提醒**，选择日期和时间 |
| 设置重复 | 在表单中开启 **重复任务**，选择每天/每周/每月及间隔 |

### 视图

- **列表视图**（默认）- 显示所有活跃任务，支持分组和标签筛选
- **按天视图** - 按截止日期分组显示任务；可切换全部 / 专注今日 / 隐藏过期
- **艾森豪威尔矩阵** - 基于紧急程度和重要性（优先级）的四象限视图

### WebDAV 同步

1. 进入 **设置 > WebDAV 同步**
2. 输入 WebDAV 服务器地址、用户名和密码
3. 点击 **测试连接** 验证
4. 点击 **保存配置**
5. 选择同步模式：
   - **自动合并**（默认）- 冲突时取 `updatedAt` 最新者
   - **本地优先** - 冲突时以本地版本为准
   - **远程优先** - 冲突时以远程版本为准
6. 点击 **开始同步**

### AI 助手

1. 进入 **设置 > AI 助手**，配置 LLM 提供商（OpenAI、DeepSeek、豆包、GLM、千问、Kimi 或自定义端点）
2. 输入 API Key 和模型名称，点击 **保存配置**
3. 切换到底部导航栏的 **AI** 标签页
4. 自然语言对话 - AI Agent 可以创建任务、分解任务、添加标签、设置优先级等
5. 低风险操作（创建、标签、分组、优先级）自动执行；高风险操作（更新、完成、删除）需要确认

### 数据导入导出

进入 **设置 > 数据管理**：

| 操作 | 格式 | 说明 |
|------|------|------|
| 导入 | `.ics` | 从日历文件导入任务 |
| 导入 | `.catodo` | 从 Catodo 完整备份恢复 |
| 导出 | `.ics` | 将活跃任务导出为日历文件 |
| 导出 | `.catodo` | 导出所有任务和设置（可选包含敏感数据） |

## 配置

### AI 提供商设置

存储在 `SharedPreferences` 中：

| 键名 | 说明 |
|------|------|
| `ai_provider_id` | 提供商标识（`openai`、`deepseek`、`doubao`、`glm`、`qwen`、`moonshot`、`custom`） |
| `ai_api_url` | API 端点地址 |
| `ai_api_key` | API 密钥 |
| `ai_model` | 模型名称 |

### WebDAV 设置

存储在 `SharedPreferences` 中：

| 键名 | 说明 |
|------|------|
| `webdav_url` | WebDAV 服务器地址 |
| `webdav_username` | 用户名 |
| `webdav_password` | 密码 |
| `sync_mode` | 冲突解决模式（`autoMerge`、`localFirst`、`remoteFirst`） |

### 按天视图设置

| 键名 | 说明 |
|------|------|
| `day_view_mode` | 视图筛选模式（`all`、`focusToday`、`hideOverdue`） |

## 项目结构

```
lib/
├── main.dart                    # 应用入口、导航、提醒调度
├── models/
│   ├── task.dart                # Task 数据模型（Isar Collection）
│   └── filter.dart              # TaskFilter 筛选条件模型
├── data/
│   └── task_dao.dart            # 数据访问对象
├── services/
│   ├── database_service.dart    # Isar 数据库单例管理
│   ├── webdav_service.dart      # WebDAV 同步服务
│   ├── ai_service.dart          # AI API 客户端
│   ├── ai_agent.dart            # AI Agent 操作定义与执行
│   ├── nlp_service.dart         # 自然语言解析服务
│   ├── ics_service.dart         # ICS 文件解析与生成
│   ├── catodo_io_service.dart   # .catodo 格式导入导出
│   ├── notification_service.dart # 通知服务（条件导出）
│   ├── repeat_task_service.dart  # 重复任务生成服务
│   └── llm_provider_registry.dart # LLM 提供商注册表
├── providers/
│   ├── isar_provider.dart       # Isar 实例 Provider
│   ├── task_providers.dart      # 任务相关 Provider
│   ├── webdav_provider.dart     # WebDAV 配置与同步模式
│   └── day_view_provider.dart   # 按天视图模式
└── ui/
    ├── screens/                 # 页面组件
    └── components/              # 可复用 UI 组件
```

## 开发

### 运行测试

```bash
# 单元测试
flutter test

# 静态分析
flutter analyze

# 模型变更后重新生成 Isar Schema
dart run build_runner build --delete-conflicting-outputs
```

### 架构

应用采用分层架构：

```
UI 层（页面、组件）
    ↓
状态管理层（Riverpod Providers）
    ↓
服务层（WebDAV、AI、通知等）
    ↓
数据层（TaskDao、Isar 数据库）
```

## 贡献

欢迎贡献！参与方式：

1. **Fork** 本仓库
2. **创建**功能分支：`git checkout -b feature/your-feature-name`
3. **提交**更改，使用清晰、描述性的提交信息
4. **测试**更改：运行 `flutter test` 和 `flutter analyze`
5. **推送**到你的 Fork：`git push origin feature/your-feature-name`
6. **发起** Pull Request 到 `main` 分支

### 贡献指南

- 遵循现有的代码风格和项目结构
- 为新功能添加测试
- PR 应聚焦于单一关注点
- 为公共 API 和复杂逻辑编写文档
- 确保 `flutter analyze` 无警告通过

## 许可证

本项目基于 GNU General Public License v3.0 许可 - 详见 [LICENSE](LICENSE) 文件。

## 联系方式

- **项目维护者**：[提交 Issue](https://github.com/your-username/catodo/issues)
- **Bug 报告**：[GitHub Issues](https://github.com/your-username/catodo/issues)
- **功能建议**：[GitHub Issues](https://github.com/your-username/catodo/issues)
