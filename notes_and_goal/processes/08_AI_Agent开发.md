# 阶段八：AI Agent 开发

## 开发目标

赋予 AI 直接操控数据库的能力，让 AI 帮用户：
1. 添加任务
2. 分解任务（拆解为子任务并自动创建）
3. 调整任务优先级
4. 给任务加标签
5. 给任务加分组
6. 完成任务
7. 删除任务
8. 查询任务列表

## 技术方案：Prompt 指令 + 结构化 JSON Action

### 方案概述

在 system prompt 中定义一套"指令协议"，LLM 根据用户意图返回包含 `reply`（自然语言回复）和 `actions`（操作指令列表）的 JSON，客户端解析 actions 后逐个调用 TaskDao 执行数据库操作。

**选择理由**：
- 所有 OpenAI 兼容厂商都支持，无需 Function Calling
- 复用现有 `requestStructuredOutput` 的最大兼容性策略（宽容解析 JSON）
- 实现简单，单次请求即可完成"理解意图 + 执行操作 + 回复用户"
- 安全可控：客户端决定是否执行，可加确认环节

### 指令协议设计

#### LLM 返回格式

```json
{
  "reply": "好的，我帮你创建了一个高优先级任务「完成报告」",
  "actions": [
    {
      "type": "create_task",
      "params": {
        "title": "完成报告",
        "priority": 3,
        "groupName": "工作",
        "tags": ["报告", "紧急"]
      }
    }
  ]
}
```

#### 支持的 Action 类型

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

#### 上下文注入

为了让 LLM 理解当前任务状态，每次请求时注入任务摘要上下文：

```
【当前任务上下文】
活跃任务共 12 个：
- [id:1] 完成季度报告 | 优先级:高 | 分组:工作 | 标签:[报告] | 截止:2026-06-10
- [id:2] 买牛奶 | 优先级:低 | 分组:生活 | 标签:[购物]
- [id:3] 学习 Flutter | 优先级:中 | 标签:[学习,编程]
...
可用分组: [工作, 生活, 学习]
可用标签: [报告, 购物, 学习, 编程, 紧急]
```

**上下文构建策略**：
- 只注入未完成、未删除的任务摘要
- 最多注入 50 个任务（避免 token 过多）
- 包含 id、title、priority、groupName、tags、dueDate 关键字段
- 附加当前所有分组和标签列表，便于 LLM 复用已有分类

### System Prompt 设计

```
你是一个任务管理 AI Agent，可以直接帮用户管理任务。

你可以执行以下操作：
- create_task: 创建新任务（参数: title必填, priority可选1-3, description可选, tags可选数组, groupName可选, dueDate可选YYYY-MM-DD）
- update_task: 更新任务（参数: taskId必填, 其他字段可选）
- complete_task: 完成任务（参数: taskId必填）
- delete_task: 删除任务（参数: taskId必填）
- decompose_task: 分解任务（参数: taskId必填, subtasks数组必填[{title, priority?}]）
- add_tag: 添加标签（参数: taskId必填, tag必填）
- remove_tag: 移除标签（参数: taskId必填, tag必填）
- set_group: 设置分组（参数: taskId必填, groupName必填）
- set_priority: 设置优先级（参数: taskId必填, priority必填1-3）

规则：
1. 优先复用已有的分组和标签，除非用户明确要求新建
2. priority: 1=低, 2=中, 3=高
3. 操作已有任务时必须使用 taskId
4. 不确定用户意图时，只返回 reply 不执行 action
5. 分解任务时，子任务数量建议 2-5 个

你必须返回 JSON 格式：
{"reply": "自然语言回复", "actions": [{"type": "操作类型", "params": {参数}}]}

如果没有需要执行的操作，actions 为空数组。
```

### 安全与确认机制

**自动执行（无需确认）**：
- `create_task`：创建任务风险低
- `add_tag`、`set_group`、`set_priority`：修改属性风险低
- `decompose_task`：分解任务风险低

**需要确认**：
- `delete_task`：删除不可逆，需用户确认
- `complete_task`：标记完成影响状态，需用户确认
- `update_task`（修改 title/description）：修改内容需确认

**确认 UI**：在聊天界面中，AI 回复后显示操作预览卡片，用户点击"确认执行"才真正调用 DAO。

### 执行流程

```
用户输入
  ↓
构建上下文（任务摘要 + 分组/标签列表）
  ↓
发送给 LLM（system prompt + 上下文 + 用户消息）
  ↓
解析 LLM 返回的 JSON
  ↓
├── 有 actions 且无需确认 → 直接执行 DAO 操作 → 刷新 UI → 回复用户
├── 有 actions 且需确认 → 显示预览卡片 → 用户确认 → 执行 → 回复用户
└── 无 actions → 直接显示 reply
  ↓
操作结果反馈给用户（成功/失败）
```

## 具体任务

### 8.1 创建 AI Agent Action 定义

- 创建 `lib/services/ai_agent.dart`
- 定义 `AgentAction` 数据类：type, params
- 定义 `AgentResponse` 数据类：reply, actions 列表
- 定义所有 action 类型的枚举和参数校验

### 8.2 创建上下文构建器

- 在 `ai_agent.dart` 中实现 `buildContext(List<Task> tasks)` 方法
- 输入：当前活跃任务列表
- 输出：格式化的任务摘要文本 + 分组/标签列表
- 限制最多 50 个任务，避免 token 超限

### 8.3 创建 Action 执行器

- 在 `ai_agent.dart` 中实现 `executeAction(AgentAction action, TaskDao dao)` 方法
- 根据 action.type 调用对应的 DAO 方法
- 返回 `ActionResult`（success, message, data?）
- 处理异常情况（taskId 不存在、参数无效等）

### 8.4 创建确认机制

- 定义哪些 action 需要确认：`delete_task`, `complete_task`, `update_task`
- 在 ChatMessage 中增加 `pendingActions` 字段
- UI 中显示操作预览卡片 + 确认/取消按钮

### 8.5 改造 ChatScreen

- 替换现有的"分解：/支持："前缀匹配逻辑，改为统一走 Agent 流程
- 保留快捷操作入口，但改为发送自然语言（如"帮我分解任务 XXX"）
- 新增 `_sendToAgent(String userMessage)` 方法：
  1. 构建上下文
  2. 调用 `requestStructuredOutput`（使用 Agent system prompt）
  3. 解析 `AgentResponse`
  4. 判断是否需要确认
  5. 执行或等待确认
- 新增操作预览卡片 UI
- 新增操作结果反馈 UI

### 8.6 改造 AIService

- 新增 `requestAgentAction(String userMessage, String context)` 方法
- 使用 Agent 专用的 system prompt
- 返回 `AgentResponse`（而非 `Map<String, dynamic>?`）

### 8.7 更新欢迎消息

- 更新 ChatScreen 的欢迎消息，展示 Agent 的全部能力
- 示例：
  - "帮我创建一个高优先级任务：完成季度报告"
  - "把任务「买牛奶」加到生活分组"
  - "分解任务「学习 Flutter」"
  - "把所有紧急标签的任务优先级调高"

## 测试标准

### 8.1 Action 解析测试
- [ ] 正确解析 create_task action
- [ ] 正确解析 update_task action
- [ ] 正确解析 complete_task action
- [ ] 正确解析 delete_task action
- [ ] 正确解析 decompose_task action
- [ ] 正确解析 add_tag / remove_tag action
- [ ] 正确解析 set_group / set_priority action
- [ ] 参数缺失时返回校验错误

### 8.2 上下文构建测试
- [ ] 正确格式化任务摘要
- [ ] 超过 50 个任务时截断
- [ ] 正确提取分组和标签列表
- [ ] 空任务列表时返回空上下文

### 8.3 Action 执行测试
- [ ] create_task 正确调用 DAO.insertTask
- [ ] update_task 正确调用 DAO.updateTask
- [ ] complete_task 正确设置 isCompleted
- [ ] delete_task 正确调用 DAO.softDeleteTask
- [ ] decompose_task 正确创建子任务
- [ ] add_tag / remove_tag 正确更新 tags
- [ ] set_group 正确更新 groupName
- [ ] set_priority 正确更新 priority
- [ ] taskId 不存在时返回错误

### 8.4 确认机制测试
- [ ] delete_task 需要确认
- [ ] complete_task 需要确认
- [ ] update_task（修改内容）需要确认
- [ ] create_task 不需要确认
- [ ] add_tag / set_group / set_priority 不需要确认

### 8.5 集成测试
- [ ] 用户说"创建任务" → AI 返回 create_task action → 自动执行 → 任务出现在列表
- [ ] 用户说"删除任务" → AI 返回 delete_task action → 显示确认 → 用户确认 → 任务被删除
- [ ] 用户说"分解任务" → AI 返回 decompose_task action → 自动执行 → 子任务出现在列表
- [ ] AI 返回无效 action 时优雅降级（只显示 reply）

## 依赖

无需新增依赖，复用现有：
- `dio`：HTTP 请求
- `isar`：数据库操作
- `flutter_riverpod`：状态管理
