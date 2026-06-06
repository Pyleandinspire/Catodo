# 阶段八开发笔记：AI Agent 开发

## 写作日期

2026-06-06

## 一、开发概述

为 Catodo 赋予 AI 直接操控数据库的能力，让 AI 从"只能对话"升级为"能执行操作"的 Agent。用户通过自然语言即可完成创建任务、分解任务、调整优先级、加标签、加分组、完成任务、删除任务等操作。

## 二、技术方案选型

### 三个候选方案

| 方案 | 原理 | 优点 | 缺点 |
|------|------|------|------|
| A: Function Calling | LLM 原生工具调用 | 意图识别准确，多步操作天然支持 | 依赖厂商支持，豆包等可能不兼容 |
| B: Prompt 指令模式 | system prompt 定义指令协议，LLM 返回含 actions 的 JSON | 所有厂商兼容，实现简单，复用现有架构 | 复杂多步操作需多次请求 |
| C: 混合模式 | 优先 Function Calling，不支持时降级到 Prompt 指令 | 兼顾体验和兼容性 | 实现和测试成本最高 |

### 最终选择：方案 B（Prompt 指令模式）

**理由**：
1. 复用现有 `requestStructuredOutput` 的最大兼容性策略，所有 OpenAI 兼容厂商都能用
2. 实现简单，单次请求即可完成"理解意图 + 执行操作 + 回复用户"
3. Catodo 的任务操作都是单步为主（创建/删除/改优先级），不需要复杂的多步编排
4. 安全可控：客户端决定是否执行，可加确认环节

## 三、核心设计

### 3.1 指令协议

LLM 返回格式：
```json
{
  "reply": "好的，我帮你创建了一个高优先级任务",
  "actions": [
    {"type": "create_task", "params": {"title": "完成报告", "priority": 3, "groupName": "工作"}}
  ]
}
```

9 种 Action 类型：

| Action | 参数 | 说明 |
|--------|------|------|
| `create_task` | title, priority?, description?, tags?, groupName?, dueDate? | 创建新任务 |
| `update_task` | taskId, title?, priority?, description?, tags?, groupName?, dueDate? | 更新任务字段 |
| `complete_task` | taskId | 标记任务完成 |
| `delete_task` | taskId | 软删除任务 |
| `decompose_task` | taskId, subtasks: [{title, priority?}] | 分解任务为子任务 |
| `add_tag` | taskId, tag | 给任务添加标签 |
| `remove_tag` | taskId, tag | 移除任务标签 |
| `set_group` | taskId, groupName | 设置任务分组 |
| `set_priority` | taskId, priority | 设置任务优先级 |

### 3.2 上下文注入

每次请求时注入当前任务摘要，让 LLM 知道用户有哪些任务、有哪些分组和标签：

```
【当前任务上下文】
活跃任务共 12 个：
- [id:1] 完成季度报告 | 优先级:高 | 分组:工作 | 标签:[报告] | 截止:2026-06-10
- [id:2] 买牛奶 | 优先级:低 | 分组:生活 | 标签:[购物]
...
可用分组: [工作, 生活, 学习]
可用标签: [报告, 购物, 学习, 编程, 紧急]
```

**关键设计**：
- 最多注入 50 个任务，避免 token 超限
- 包含 taskId，LLM 操作已有任务时必须引用 id
- 附加分组和标签列表，引导 LLM 复用已有分类

### 3.3 确认机制

| 操作 | 风险 | 是否需要确认 |
|------|------|-------------|
| create_task | 低 | 否 |
| add_tag / remove_tag | 低 | 否 |
| set_group / set_priority | 低 | 否 |
| decompose_task | 低 | 否 |
| complete_task | 中 | **是** |
| delete_task | 高 | **是** |
| update_task（改内容） | 中 | **是** |

确认 UI：黄色警告卡片，列出操作描述 + 确认/取消按钮。

### 3.4 执行流程

```
用户输入
  ↓
构建上下文（任务摘要 + 分组/标签列表）
  ↓
发送给 LLM（Agent system prompt + 上下文 + 用户消息）
  ↓
解析 AgentResponse（reply + actions）
  ↓
├── 低风险 actions → 自动执行 DAO 操作 → 附加结果到回复
├── 高风险 actions → 显示确认卡片 → 用户确认 → 执行
└── 无 actions → 直接显示 reply
```

## 四、新增/修改文件

### 4.1 新增：`lib/services/ai_agent.dart`

Agent 核心逻辑，包含：

- `AgentActionType` 枚举：9 种操作类型
- `AgentAction` 数据类：type + params + needsConfirmation + description
- `AgentResponse` 数据类：reply + actions 列表，支持 fromJson 解析
- `ActionResult` 数据类：success + message + data
- `buildTaskContext(List<Task> tasks)`：构建任务上下文（@visibleForTesting）
- `executeAction(AgentAction action, TaskDao dao)`：执行器，9 个 action 对应 9 个 DAO 调用
- `kAgentSystemPrompt`：Agent 专用 system prompt 常量

### 4.2 修改：`lib/services/ai_service.dart`

- 新增 `requestAgentAction({userMessage, context})` 方法
- 内部调用 `requestStructuredOutput`，使用 Agent system prompt + 上下文
- 返回 `AgentResponse`（而非 `Map<String, dynamic>?`）
- 请求失败时返回默认 AgentResponse（只有 reply，无 actions）

### 4.3 修改：`lib/ui/screens/chat_screen.dart`

**全面改造**，从"关键词匹配"升级为"Agent 流程"：

- 移除 `分解：/支持：` 前缀匹配逻辑
- 新增 `_sendToAgent()` 流程：构建上下文 → 调用 Agent → 分离确认/自动执行 → 执行 → 回复
- 新增 `_confirmActions()` / `_cancelActions()` 方法
- 新增 `_buildConfirmationCard()` 确认卡片 UI
- `ChatMessage` 数据类：`hasAddTaskAction + subTasks` → `pendingActions`
- 快捷操作菜单扩展：创建/分解/调整优先级/加标签/完成
- 副标题改为"智能任务管理 Agent"
- 欢迎消息更新，展示 Agent 全部能力

### 4.4 新增：`test/ai_agent_test.dart`

33 个单元测试，覆盖：
- AgentActionType.fromString 解析
- AgentAction.fromJson 解析 + needsConfirmation + description
- AgentResponse.fromJson 解析（完整/缺失/多 actions）
- ActionResult 成功/失败
- buildTaskContext（空列表/任务摘要/分组标签/截止日期/50 任务截断/计数）
- kAgentSystemPrompt 内容验证

## 五、踩坑与修复

### 5.1 Dart 级联操作符与 void 方法

```dart
// 错误：sort() 返回 void，不能级联调用 join()
groups.toList()..sort().join(', ')

// 修复：先排序赋值，再 join
final sortedGroups = groups.toList()..sort();
sortedGroups.join(', ')
```

### 5.2 BorderRadius 类型不匹配

```dart
// 错误：Radius 不是 BorderRadiusGeometry
borderRadius: const Radius.circular(24)

// 修复：使用 BorderRadius.all
borderRadius: const BorderRadius.all(Radius.circular(24))
```

### 5.3 枚举 firstWhere 返回可空类型

```dart
// 错误：orElse 返回 AgentActionType.values.first 但 firstWhere 推断为 AgentActionType?
static AgentActionType? fromString(String value) { ... }

// 修复：直接返回具体值，去掉 ?
static AgentActionType fromString(String value) {
  return AgentActionType.values.firstWhere(
    (e) => e.value == value,
    orElse: () => AgentActionType.createTask,
  );
}
```

## 六、测试结果

- **121/121 单元测试全部通过**
- 新增 33 个 AI Agent 测试
- 原有 88 个测试无回归

## 七、开发心得

1. **Prompt 即协议**：用 system prompt 定义指令协议比 Function Calling 更通用，虽然意图识别精度略低，但兼容性远胜。对于 Catodo 这种操作类型有限的场景，Prompt 指令模式完全够用。

2. **上下文是关键**：Agent 的能力上限取决于上下文质量。注入任务摘要让 LLM 能"看到"当前状态，这是从"对话"到"执行"的关键一步。

3. **安全分层**：不是所有操作都该自动执行。删除/完成等不可逆操作必须确认，创建/加标签等低风险操作可以自动执行。这个分层设计让用户既有效率又有安全感。

4. **从关键词到自然语言**：旧的"分解：/支持："前缀匹配是硬编码的，用户必须记住格式。Agent 模式下用户只需自然语言，LLM 自动理解意图，体验提升明显。
