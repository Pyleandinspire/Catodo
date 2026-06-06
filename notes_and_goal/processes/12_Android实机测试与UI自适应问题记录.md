# 12_Android 实机测试与 UI 自适应问题记录

## 一、本次开发背景

经过前几轮跨平台适配（详见 `11_跨平台兼容性开发笔记.md`），Catodo 应用的 debug APK 已能在 Android 16 设备上正常打开运行。本文档记录后续测试中发现的新问题以及对应的修复方案。

## 二、当前测试状态

### 已确认可运行

- ✅ `build\app\outputs\flutter-apk\app-debug.apk` 已在 Android 16 手机上成功安装并启动
- ✅ Flutter UI 可正常渲染（不再黑屏）
- ✅ 主导航与基础页面切换功能正常

### 测试覆盖情况

- ⚠️ **测试尚未完全完成**，用户在初步测试中已发现以下问题，仍有大量功能未测试

## 三、新发现的问题

### 问题 1：Release APK 构建失败（R8 缺失类）

**现象**：
执行 `flutter build apk`（release 模式）时报错：

```
ERROR: R8: Missing class com.google.android.play.core.splitcompat.SplitCompatApplication
Missing class com.google.android.play.core.splitinstall.SplitInstallException
... 等共 11 个 Missing class
Execution failed for task ':app:minifyReleaseWithR8'.
```

**根本原因**：

- 在前一轮修复 Android 崩溃问题时启用了 `isMinifyEnabled = true`（R8 代码压缩 / 混淆）
- Flutter Embedding 中的 `PlayStoreDeferredComponentManager` 引用了 Google Play Core 库
- Catodo 项目并不需要 Play Store 动态功能模块（Deferred Components），但 R8 仍然要求 keep 这些类
- 当前的 `proguard-rules.pro` 只保留了 Isar 和 Flutter 基础类，未处理 Play Core 缺失类

**修复方案（待实施）**：
两种方案，二选一：

1. **方案 A（推荐）**：在 `proguard-rules.pro` 中显式忽略 Play Core 相关类

   ```
   -dontwarn com.google.android.play.core.**
   -dontwarn com.google.android.play.core.splitcompat.**
   -dontwarn com.google.android.play.core.splitinstall.**
   -dontwarn com.google.android.play.core.tasks.**
   ```

2. **方案 B**：先关闭 release 的 R8 压缩（`isMinifyEnabled = false`），保证可出包，后续再优化

> 注：debug APK 不受影响，因为 debug 默认不启用 R8。

### 问题 2：手机端 UI 超出屏幕、出现 Overflow 报错

**现象**：

- 当前界面在桌面端设计时尺寸偏大
- 在手机（窄屏）上运行时，部分页面/组件出现 `RenderFlex overflowed by X pixels` 报错
- 黄黑斜纹的 Overflow 警告条出现在屏幕边缘

**可能的根因**：

1. **固定宽度/高度**：某些组件使用了硬编码的 `width: 600` 等固定值
2. **Row/Column 未使用 `Expanded` / `Flexible`**：导致子元素无法压缩
3. **未处理键盘弹出**：`adjustResize` 模式下键盘弹出会压缩可用高度
4. **NavigationRail 未限制宽度**：在中间宽度屏幕上侧边栏占用过多空间
5. **Dialog / BottomSheet 内容溢出**：弹窗内容未使用 `SingleChildScrollView` 包裹
6. **任务卡片内 Wrap 未生效**：标签数量多时未自动换行

**修复方案（待实施）**：
按优先级逐项排查：

| 优先级 | 修复项                  | 涉及文件（推测）                        |
| ------ | ----------------------- | --------------------------------------- |
| P0     | 任务列表卡片 Overflow   | `lib/ui/components/task_item.dart`      |
| P0     | 任务表单页面 Overflow   | `lib/ui/screens/task_form_screen.dart`  |
| P0     | 艾森豪威尔四象限页面    | `lib/ui/screens/eisenhower_screen.dart` |
| P1     | 各 Dialog / BottomSheet | 全局排查                                |
| P1     | 设置页面                | `lib/ui/screens/settings_screen.dart`   |
| P2     | 字体大小响应式调整      | 主题与文本组件                          |

**通用修复技巧**：

- `Row` → 使用 `Expanded` 包裹可压缩子项
- 横向标签列表 → 改用 `Wrap` 或 `SingleChildScrollView(scrollDirection: Axis.horizontal)`
- 弹窗 → 内容用 `SingleChildScrollView` 包裹
- 固定尺寸 → 改用 `LayoutBuilder` + 比例计算
- 文本 → 添加 `overflow: TextOverflow.ellipsis` 和 `maxLines`

### 问题 3：部分功能未完全实现 / 行为异常

**现象**：
用户描述「还有一些功能并不能正常实现」，但暂未具体定位到哪些功能。

**后续测试计划**：

- [ ] 任务创建 / 编辑 / 删除
- [ ] 任务完成状态切换
- [ ] 优先级 / 截止日期 / 标签 / 分组
- [ ] 提醒功能（通知调度）
- [ ] 循环任务（rrule）
- [ ] 筛选与排序
- [ ] AI 对话与 Agent 功能
- [ ] WebDAV 同步
- [ ] 数据导入 / 导出
- [ ] 艾森豪威尔矩阵
- [ ] 设置项持久化

## 四、对前几轮开发的关键内容回顾

### 第一轮：跨平台基础适配

- **条件导入 + 抽象层**：`NotificationService` 分裂为 `_io.dart` 和 `_stub.dart`，通过 `dart.library.io` 条件导出
- **响应式导航**：`AdaptiveNavigation` 使用 `LayoutBuilder` 在 600dp 阈值下切换 `NavigationBar` 与 `NavigationRail`
- **跨平台文件操作**：使用 `file_picker` 的 `bytes` 取代 `dart:io File`
- **权限声明**：`AndroidManifest.xml` 加入 `POST_NOTIFICATIONS`、`SCHEDULE_EXACT_ALARM` 等
- **统一品牌**：所有平台应用名规范为 `Catodo`

### 第二轮：Android 崩溃修复

- **桌面平台判断**：`window_manager` 仅在 Windows/macOS/Linux 初始化，避免 Android 上 `MissingPluginException`
- **权限请求容错**：`Permission.notification.request()` 外层 `try-catch`
- **时区数据库初始化**：`tz_data.initializeTimeZones()` 在通知服务 `initialize()` 中调用
- **Isar Inspector 仅 Debug**：`inspector: kDebugMode`
- **ProGuard 规则**：新建 `proguard-rules.pro` 保留 Isar / Flutter 原生方法

### 第三轮：Android 16 黑屏修复

- **启动顺序重构**：`runApp()` 提前到所有 `await` 之前，避免原生层崩溃导致 UI 永远不渲染
  ```dart
  void main() {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const ProviderScope(child: CatodoApp())); // 先渲染
    _initializeServices(); // 异步初始化，不阻塞 UI
  }
  ```
- **Edge-to-Edge 适配**：Android 15+ 强制 edge-to-edge，更新 `styles.xml` 使用 Material 主题 + 透明状态栏/导航栏，添加 `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`
- **数据库超时保护**：`Isar.open()` 加 10 秒超时，超时显示明确错误而非无限黑屏
- **全局错误处理**：注册 `FlutterError.onError` 和 `PlatformDispatcher.instance.onError`
- **SDK 版本固定**：`minSdk = 21`, `targetSdk = 36`

### 已通过的测试

- ✅ 27 个 Dart 单元 / Widget 测试全部通过
- ✅ Windows debug 编译
- ✅ Android debug APK 编译并在 Android 16 实机运行

## 五、本次开发的所有代码改动清单

> 以下是本次（从「P0/P1 跨平台兼容」→「Android 启动崩溃修复」→「Android 16 黑屏修复」→「写测试用例」共三轮）对项目代码所做的完整改动清单。

### 5.1 新建的文件

| 文件路径                                                           | 用途                                                          |
| ------------------------------------------------------------------ | ------------------------------------------------------------- |
| `lib/services/notification_service.dart`                           | 通知服务条件导出入口，通过 `dart.library.io` 自动选择平台实现 |
| `lib/services/notification_service_io.dart`                        | 支持 `dart:io` 的平台（Android/iOS/macOS）通知完整实现        |
| `lib/services/notification_service_stub.dart`                      | 不支持通知的平台（Windows/Linux/Web）空实现                   |
| `lib/ui/components/adaptive_navigation.dart`                       | 响应式导航组件（窄屏 BottomNav / 宽屏 NavigationRail）        |
| `android/app/proguard-rules.pro`                                   | R8/ProGuard 保留规则（Isar、Flutter 原生方法）                |
| `test/widget_test.dart`                                            | 27 个测试用例（7 个测试套件）                                 |
| `notes_and_goal/processes/11_跨平台兼容性开发笔记.md`              | 跨平台开发笔记                                                |
| `notes_and_goal/processes/12_Android实机测试与UI自适应问题记录.md` | 本文档                                                        |

### 5.2 修改的 Dart 文件

#### `lib/main.dart`

- ➕ 引入 `dart:io`、`dart:ui`、`flutter/services.dart`、`window_manager`、`permission_handler`
- ➕ 新增 `_isDesktopPlatform()` 函数，精确判断桌面平台
- 🔄 重构 `main()` 函数：
  - 注册 `FlutterError.onError` 全局错误处理
  - 注册 `PlatformDispatcher.instance.onError` 异步错误处理
  - 配置 `SystemUiOverlayStyle` 透明状态栏 / 导航栏
  - 启用 `SystemUiMode.edgeToEdge` 适配 Android 15+
  - **先 `runApp()` 渲染 UI，再异步初始化服务**（Android 16 黑屏关键修复）
- ➕ 新增 `_initializeServices()` 异步初始化函数（权限请求 + 通知服务）
- 🔄 桌面端窗口配置改为非阻塞 `.then().catchError()`

#### `lib/services/database_service.dart`

- ➕ 引入 `dart:async`、`flutter/foundation.dart`
- 🔄 `inspector: true` → `inspector: kDebugMode`（仅 Debug 启用）
- ➕ `Isar.open()` 添加 10 秒超时保护，防止 Android 16 上原生层挂起导致无限黑屏
- ➕ 失败时 `debugPrint` 记录详细错误信息
- ➕ 实例校验失败后置空 `_instance = null` 再重建

#### `lib/services/notification_service_io.dart`（修改自原 `notification_service.dart`）

- ➕ 引入 `package:timezone/data/latest.dart`
- ➕ 在 `initialize()` 中调用 `tz_data.initializeTimeZones()` 初始化时区数据库
- ➕ 所有方法外层包裹 `try-catch`，原生层异常不影响应用运行
- ➕ `_initialized` 标志位防止未初始化时调用

#### `lib/ui/screens/data_management_screen.dart`

- 🗑️ 移除 `import 'dart:io'`、`import 'dart:convert'`
- 🔄 文件导入：`File(path).readAsString()` → `result.files.single.bytes` + `utf8.decode()`
- 🔄 文件导出：移除 `dart:io` File fallback，统一使用 `FilePicker.platform.saveFile(bytes: ...)`

### 5.3 修改的 Android 配置

#### `android/app/build.gradle.kts`

- 🔄 `compileSdk` → `36`
- 🔄 `minSdk = flutter.minSdkVersion` → `minSdk = 21`（明确）
- 🔄 `targetSdk = flutter.targetSdkVersion` → `targetSdk = 36`（明确）
- ➕ `compileOptions` 启用 `isCoreLibraryDesugaringEnabled = true`
- ➕ `dependencies` 添加 `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`
- ➕ `kotlin { compilerOptions { jvmTarget = JVM_17 } }`
- ➕ `buildTypes.release` 启用 `isMinifyEnabled = true` 并引用 `proguard-rules.pro`

#### `android/app/src/main/AndroidManifest.xml`

- 🔄 `android:label="catodo"` → `android:label="Catodo"`
- ➕ 添加权限：
  - `android.permission.POST_NOTIFICATIONS`
  - `android.permission.SCHEDULE_EXACT_ALARM`
  - `android.permission.USE_EXACT_ALARM`
  - `android.permission.RECEIVE_BOOT_COMPLETED`

#### `android/app/src/main/res/values/styles.xml`

- 🔄 `Theme.Light.NoTitleBar` → `Theme.Material.Light.NoActionBar`
- ➕ 添加 `android:statusBarColor` 和 `android:navigationBarColor` 为透明（edge-to-edge 适配）

#### `android/app/src/main/res/values-night/styles.xml`

- 🔄 `Theme.Black.NoTitleBar` → `Theme.Material.NoActionBar`
- ➕ 同上，添加透明状态栏 / 导航栏

#### `android/app/proguard-rules.pro`（新建）

- ➕ 保留 `dev.isar.**`
- ➕ 保留 `io.flutter.**`、`io.flutter.plugins.**`
- ➕ 保留 native 方法签名（`-keepclasseswithmembernames class * { native <methods>; }`）
- ➕ 保留 `*Annotation*`

### 5.4 修改的桌面端配置

#### `windows/runner/main.cpp`

- 🔄 窗口标题：`catodo` → `Catodo`

#### `linux/runner/my_application.cc`

- 🔄 窗口标题 / HeaderBar 标题：`catodo` → `Catodo`
- 🔄 背景色：`#000000` → `#FFFFFF`（修复启动黑屏闪烁）

#### `macos/Runner/Release.entitlements` 和 `DebugProfile.entitlements`

- ➕ `com.apple.security.network.client` = `true`（允许网络访问）

### 5.5 修改的 Web 配置

#### `web/index.html`

- 🔄 `<title>` / description / apple-mobile-web-app-title：`catodo` → `Catodo`

#### `web/manifest.json`

- 🔄 `name` / `short_name` / `description`：`catodo` → `Catodo`

### 5.6 修改的依赖配置

#### `pubspec.yaml`

- ➕ `permission_handler: ^11.3.0`（Android 13+ 通知权限）
- ➕ `window_manager: ^0.4.3`（桌面端窗口配置）

### 5.7 第三方插件临时补丁（pub cache）

> 这些是临时修改，长期方案是升级到支持新版 compileSdk 的插件版本。

| 插件                                                           | 修改                                            |
| -------------------------------------------------------------- | ----------------------------------------------- |
| `file_picker-8.0.7/android/build.gradle`                       | `compileSdk 34` → `36`                          |
| `flutter_plugin_android_lifecycle-2.0.35/android/build.gradle` | `compileSdk = flutter.compileSdkVersion` → `36` |
| `isar_flutter_libs-3.1.0+1/android/build.gradle`               | `compileSdkVersion 30` → `36`                   |

### 5.8 测试用例覆盖

`test/widget_test.dart` 包含 7 个测试套件、27 个测试用例：

| 套件                   | 用例数 | 覆盖内容                                   |
| ---------------------- | ------ | ------------------------------------------ |
| 1. 应用启动测试        | 2      | 启动不崩溃、加载指示器                     |
| 2. Task 模型测试       | 5      | 默认值、自定义值、copyWith、列表副本独立性 |
| 3. TaskFilter 模型测试 | 3      | 默认值、copyWith、字段保留                 |
| 4. 通知服务测试        | 2      | 单例、方法调用不抛异常                     |
| 5. UI 组件渲染测试     | 5      | 窄/宽屏导航切换、TaskItem 渲染             |
| 6. 边界条件测试        | 8      | 空标题、极长标题、大量标签、日期边界       |
| 7. 平台兼容性测试      | 2      | 条件导入、方法签名一致性                   |

### 5.9 改动统计

| 类型                        | 数量         |
| --------------------------- | ------------ |
| 新建 Dart 文件              | 4            |
| 修改 Dart 文件              | 4            |
| 新建 Android 配置           | 1            |
| 修改 Android 配置           | 5            |
| 修改桌面 / Web / macOS 配置 | 6            |
| 修改 `pubspec.yaml`         | 1            |
| pub cache 插件临时补丁      | 3            |
| 新建测试文件                | 1（27 用例） |
| 新建文档                    | 2            |
| **改动文件总数**            | **27**       |

## 六、本轮需要完成的任务清单

| ID  | 任务                                                    | 优先级 | 状态 |
| --- | ------------------------------------------------------- | ------ | ---- |
| T1  | 修复 release APK R8 缺失类问题（添加 `-dontwarn` 规则） | P0     | 待办 |
| T2  | 全面排查 UI Overflow 问题，修复手机端布局               | P0     | 待办 |
| T3  | 完成端到端功能测试，列出所有未正常工作的功能            | P0     | 待办 |
| T4  | 针对 T3 发现的问题逐项修复                              | P0     | 待办 |
| T5  | 编写 / 补充对应功能的自动化测试用例                     | P1     | 待办 |
| T6  | release APK 实机验证                                    | P1     | 待办 |

## 七、UI 响应式优化建议

为彻底解决手机端 UI 过大的问题，建议在后续开发中遵循：

1. **避免固定尺寸**：优先使用 `Expanded` / `Flexible` / 比例布局
2. **使用响应式断点**：定义统一的断点常量
   ```dart
   const double kMobileBreakpoint = 600;
   const double kTabletBreakpoint = 900;
   ```
3. **字体响应式**：使用 `MediaQuery.textScalerOf(context)` 适配用户字体设置
4. **滚动包裹**：所有表单页面默认外层包 `SingleChildScrollView`
5. **横向溢出处理**：长文本使用 `Expanded` + `ellipsis`，标签使用 `Wrap`
6. **Dialog 限制最大高度**：避免内容过多撑爆屏幕
   ```dart
   ConstrainedBox(
     constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
     child: ...
   )
   ```

## 八、备注

- 当前 debug APK 已可用，可以继续在手机上进行更多功能测试
- Release APK 的 R8 问题不影响 debug 测试，但发布前必须修复
- 后续每轮修复完成后，应同步更新本文档的"任务清单"状态
