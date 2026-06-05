# Smart Todo App 技术实现详细设计文档

本框架文档旨在指导基于 **Flutter & Dart** 的智能待办清单（To-Do List）应用的落地开发。应用采用本地优先（Local-First）架构，融合 AI 语义理解与心理疏导接口，确保海量数据下的极致流畅度与高隐私性。

## 1. 系统架构蓝图与数据流向

整个应用的核心逻辑分为三层：**数据源层（Isar/WebDAV）**、**状态派生层（Riverpod）与UI渲染层**。

### 1.1 反应式数据流拓扑

为了确保海量任务下不掉帧，数据流向必须是单向且反应式（Reactive）的：

```
[Isar Database (盘点/变更)] 
      │
      ▼ (通过 Isar .watch() 抛出异步流)
[Riverpod StreamProvider / Notifier]
      │
      ▼ (使用 .select() 过滤不必要字段，精确驱动)
[UI Layer (局部 Widget 刷新)]
```

### 1.2 异步混合同步与 AI 拓扑

- **WebDAV：** 定时或手动触发，将 Isar 的 `.isar` 数据库文件或特定 JSON 增量包上下载至用户网盘，本地进行时间戳对比（Last-Write-Wins）。
    
- **AI 接口：** 客户端直连用户配置的 API 端点，通过端到端 HTTPS 请求，完全不经过第三方中转服务器。
    

## 2. 数据持久化层设计（Isar Database）

为了保证上万条数据下的秒级检索与动态刷新，我们利用 Isar 的**强类型对象存储**与**多字段复合索引**。

### 2.1 数据模型（Dart Entities）

#### Task 实体（核心任务表）

Dart

```
import 'package:isar/isar.dart';

part 'task.g.dart';

@collection
class Task {
  Id id = Isar.autoIncrement; // 自增ID

  @Index(type: IndexType.value)
  late String title;
  
  String? description;
  
  @Index()
  late bool isCompleted;

  // 优先级：0-无, 1-低(不重要不紧急), 2-中(重要不紧急/紧急不重要), 3-高(重要紧急)
  @Index()
  late int priority; 

  @Index()
  DateTime? dueDate; // 截止日期
  
  List<String> tags = []; // 标签数组
  
  String? groupName; // 列表/项目分组名称

  // 重复任务规则字符串（RFC 5545 RRULE），如 "FREQ=DAILY;INTERVAL=1"
  String? rrule; 
  bool isRepeatParent = false; // 是否为循环任务的母体
  
  @Index()
  late DateTime createdAt;
  late DateTime updatedAt; // 用于 WebDAV 冲突合并
  late bool isDeleted; // 软删除标记，用于同步

  // 提醒时间戳（可支持单任务多个提醒点）
  List<DateTime> reminderTimes = [];
}
```

### 2.2 性能优化技术细节

1. **复合索引优化：** 针对“艾森豪威尔矩阵视图”，建立 `[priority + isCompleted]` 的复合索引，避免全表扫描。
    
2. **异步局部监听：** UI 层**禁止**直接读取全局 `isar.tasks.where().findAll()`。必须使用 Isar 的 `watchLazy()` 或 Riverpod 的流容器，仅在对应 Task 的 `id` 发生变更时，才重绘当前 Row。
    

## 3. 状态管理与视图流转（Riverpod）

Riverpod 在本项目中充当“内存数据总线”，负责将 Isar 中的原始数据动态剪裁为不同的视图视图。

### 3.1 核心 Provider 树体系

- **`isarProvider` (Provider):** 全局单例，提供 Isar 实例指针。
    
- **`taskListProvider` (StreamNotifierProvider):** 绑定 Isar 的 `watch()` 流，实时向 UI 抛出当前最新的**未删除未完成**的任务全集。
    
- **`filterConditionProvider` (StateProvider):** 维护当前的筛选状态，数据结构如下：
    
    Dart
    
    ```
    class TaskFilter {
      final String? selectedGroup;
      final int? selectedPriority;
      final String? selectedTag;
      TaskFilter({this.selectedGroup, this.selectedPriority, this.selectedTag});
    }
    ```
    

### 3.2 动态视图流转实现（派生状态）

#### 艾森豪威尔矩阵与自定义筛选处理器

Dart

```
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 基础未完成任务流
final activeTasksProvider = StreamProvider<List<Task>>((ref) {
  final isar = ref.watch(isarProvider);
  return isar.tasks.where().isCompletedEqualTo(false).and().isDeletedEqualTo(false).watch();
});

// 派生：经过 UI 筛选条件过滤后的任务列表
final filteredTasksProvider = Provider<List<Task>>((ref) {
  final asyncTasks = ref.watch(activeTasksProvider);
  final filter = ref.watch(filterConditionProvider);

  return asyncTasks.when(
    data: (tasks) {
      return tasks.where((task) {
        final matchGroup = filter.selectedGroup == null || task.groupName == filter.selectedGroup;
        final matchPriority = filter.selectedPriority == null || task.priority == filter.selectedPriority;
        final matchTag = filter.selectedTag == null || task.tags.contains(filter.selectedTag);
        return matchGroup && matchPriority && matchTag;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// 派生：艾森豪威尔矩阵 - 重要且紧急视图 (Priority == 3)
final urgentImportantTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(filteredTasksProvider);
  return tasks.where((task) => task.priority == 3).toList();
});
```

## 4. 循环任务与本地通知（通知体系与动态生成）

应用采用**动态生成法**处理重复任务，避免在数据库中一次性塞入过多未来数据。

### 4.1 重复任务状态机逻辑

当一个带有 `rrule` 的任务被触发“完成”动作时，不执行物理删除，而是执行以下**动态演进算法**：

```
[用户勾选完成当前任务]
         │
         ▼
[读取当前任务的 rrule 字符串]
         │
         ▼
[利用 rrule 库计算出下一个符合条件的 DateTime]
         │
         ▼
 ┌───────┴────────────────────────────────────────┐
 ▼ (步骤一)                                       ▼ (步骤二)
[将当前任务 isCompleted 设为 true]        [克隆新任务：继承 title/priority/rrule]
[更新其 updatedAt 并保存]                 [设置新任务 dueDate = 下一个计算出的日期]
                                          [为其计算并绑定新的本地通知闹钟（Reminder）]
                                          [isar.tasks.put(新任务)]
```

### 4.2 本地通知细节（`flutter_local_notifications` + `timezone`）

#### 闹钟注册机服务

Dart

```
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> scheduleTaskReminder(Task task) async {
    if (task.dueDate == null || task.reminderTimes.isEmpty) return;

    for (var i = 0; i < task.reminderTimes.length; i++) {
      final reminderTime = task.reminderTimes[i];
      if (reminderTime.isBefore(DateTime.now())) continue;

      // 使用唯一 ID：将任务的 Isar ID 与索引进行位运算组合，防止冲突
      final notificationId = task.id * 10 + i;

      await _plugin.zonedSchedule(
        notificationId,
        task.title,
        task.description ?? "你有待办任务即将截止",
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'todo_reminders_channel',
            '任务提醒',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // 确保休眠时精准唤醒
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelTaskReminder(int taskId) async {
    // 连带清除该任务下的所有子弹窗提醒（0-9）
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(taskId * 10 + i);
    }
  }
}
```

## 5. 自然语言解析（NLP）与智能输入混合方案

为了兼顾无网环境下的即时反馈与复杂场景下的高智能，系统输入框采用**双轨拦截机制**。

### 5.1 混合解析控制流

当用户在输入框内键入文字并回车时：

```
     [用户键入：明天下午3点和老张开会]
                   │
                   ▼
     [检测网络状态 与 用户是否配置大模型API]
                   │
         ┌─────────┴─────────┐
         ▼ (有网 且 已配API)  ▼ (无网 或 未配API)
   【云端大模型降维解析】     【本地正则高速引擎】
         │                   │
         │ (调用自定义 API)   │ (利用 RegEx 拦截关键词)
         ▼                   ▼
   提取出：               提取出：
   - Title: "和老张开会"   - Title: "和老张开会"
   - Date: 2026-06-06     - Date: 2026-06-06
   - Time: 15:00:00       - Time: 15:00:00
   - Confidence: 99%      - Confidence: 70%
         │                   │
         └─────────┬─────────┘
                   ▼
           [回显到 UI 供用户微调]
```

### 5.2 本地正则引擎核心策略

在本地解析时，使用 Dart 的 `RegExp` 静态拦截高频时间特征，为大模型方案兜底：

- **日期映射：** `(?<today>今天)|(?<tomorrow>明天)|(?<dat>后天)`
    
- **周几映射：** `周[一二三四五六日]|星期[1-7]`
    
- **时间点映射：** `(?<hour>\d{1,2})点((?<minute>\d{1,2})分)?` 或 `(?<hm>\d{2}:\d{2})`
    

系统通过硬编码逻辑将匹配到的字段转化为今日或明日的 `DateTime` 偏移量。

## 6. 用户自定义 API 与 AI 核心亮点落地

应用本身**不预置、不硬编码**任何商业大模型的 API Key。系统提供统一的统一请求适配器，支持用户填入自己的 `API Key`、`Base URL` 和 `Model Name`（兼容 OpenAI / Gemini / DeepSeek 格式）。

### 6.1 通用 OpenAIChatAdapter 实现

Dart

```
import 'package:dio/dio.dart';

class CustomAIAdapter {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final Dio _dio = Dio();

  CustomAIAdapter({required this.apiKey, required this.baseUrl, required this.modelName});

  Future<Map<String, dynamic>?> requestStructuredOutput({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/v1/chat/completions',
        options: Options(headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': modelName,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt}
          ],
          // 强制启用 JSON Mode 确保返回结果可被解析
          'response_format': {'type': 'json_object'}, 
          'temperature': 0.3,
        },
      );

      final String rawContent = response.data['choices'][0]['message']['content'];
      return jsonDecode(rawContent) as Map<String, dynamic>;
    } catch (e) {
      // 优雅降级：向 UI 抛出友好错误提示，引导检查配置或网络
      return null;
    }
  }
}
```

### 6.2 核心应用场景 System Prompt 工程

#### 场景 A：任务分解 (Task Decomposition)

- **System Prompt:**
    
    Plaintext
    
    ```
    你是一个严谨的个人效能专家。请将用户输入的宏大任务拆解为3-5个具体可执行的子任务。
    你必须返回标准的JSON格式，结构体如下，不要包含任何多余的markdown标记或Markdown代码块：
    {
      "tasks": [
        {"title": "子任务名称", "priority": 1, "estimatedMinutes": 30},
        {"title": "子任务名称", "priority": 2, "estimatedMinutes": 45}
      ]
    }
    注意：priority用1(不重要)到3(极为重要)表示。
    ```
    

#### 场景 B：超时情绪支持与改进建议 (Overdue Chat & Empathy)

当触发任务延期点击时，App 调起对话 UI，发送如下隐形设定：

- **System Prompt:**
    
    Plaintext
    
    ```
    你是一位温暖、富有极强共情心的心理咨询师，同时也是一位时间管理教练。
    用户的任务['$taskTitle']本应在['$taskDueDate']完成，但现在已经超时了。用户目前可能感到自责、焦虑或有些拖延。
    请遵循以下对话指南：
    1. 绝对不要指责用户，首先使用温柔的语气认可他们之前付出的努力，缓解他们的挫败感。
    2. 采用引导式提问（例如：“是不是这个任务拆解得不够具体？”或“过程中遇到了什么意外阻碍吗？”），帮助用户厘清原因。
    3. 给出1-2条非常具体的、微小的、能立刻上手的行动建议（例如：先坐在书桌前写5分钟字）。
    请保持语气短小精悍、温暖治愈，不要长篇大论。
    ```
    

## 7. 数据交换与跨平台同步

### 7.1 WebDAV 增量同步策略

由于采用 `webdav_client`，为了节省电量和流量，系统不采用全量覆盖，而是采用**元数据时间戳差异对齐法**：

1. **准备同步包：** App 将本地自上次同步以来，所有 `updatedAt` 大于服务器同步锚点的时间、且 `isDeleted` 标记或未标记的任务，序列化为一个精简的 `sync_delta.json`。
    
2. **拉取并合并：** 先从 WebDAV 下载云端包，比对每条记录的 `id` 与 `updatedAt`：
    
    - 若 `Local.updatedAt > Cloud.updatedAt` -> **保留本地，标记待上传**。
        
    - 若 `Local.updatedAt < Cloud.updatedAt` -> **用云端数据覆盖本地 Isar 记录**。
        
3. **推回云端：** 将合并完成后的最新状态重新打包上传，更新同步时间戳。
    

### 7.2 `.ics` 文件生成与解析规范（iCalendar）

#### 导出 `.ics` 核心串行化逻辑

使用纯 Dart 拼接符合 RFC 5545 规范的字符串，并通过 `share_plus` 发送：

Dart

```
String convertTaskToIcs(Task task) {
  final buffer = StringBuffer();
  buffer.writeln('BEGIN:VCALENDAR');
  buffer.writeln('VERSION:2.0');
  buffer.writeln('PRODID:-//SmartTodo//TaskApp//CN');
  buffer.writeln('BEGIN:VEVENT');
  buffer.writeln('UID:todo_task_${task.id}@smarttodo.com');
  buffer.writeln('SUMMARY:${task.title}');
  if (task.description != null) buffer.writeln('DESCRIPTION:${task.description}');
  if (task.dueDate != null) {
    final dateStr = task.dueDate!.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first + 'Z';
    buffer.writeln('DTSTART:$dateStr');
    buffer.writeln('DTEND:$dateStr');
  }
  if (task.rrule != null) buffer.writeln('RRULE:${task.rrule}');
  buffer.writeln('END:VEVENT');
  buffer.writeln('END:VCALENDAR');
  return buffer.toString();
}
```

通过 `icalendar_parser` 做逆向解析时，只需读取字符串中对应的 `SUMMARY` -> `title`，`RRULE` -> `rrule` 并批量反序列化注入 `isar` 事务即可。