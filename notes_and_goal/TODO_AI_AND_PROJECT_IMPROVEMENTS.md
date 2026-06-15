# Catodo 改进代办清单

> 本文件为 `cursor-agent-team/ai_workspace/todos/TODO_AI_AND_PROJECT_IMPROVEMENTS.md` 的同步副本。
> 创建日期：2026-06-15
> 详细分析见 `cursor-agent-team/ai_workspace/scratchpad/AI-001-analysis.md`。
>
> **请只在 `cursor-agent-team/ai_workspace/todos/...` 那份做改动，本文件用于在项目笔记目录中留底参考。**

## 标识说明

- 状态：⬜ 待办 / 🔵 进行中 / ✅ 完成 / ⏸ 暂搁
- 优先级：P0 立刻 / P1 下一批 / P2 路线图

---

## 一、AI 功能改进（本轮 P0）

| ID | 状态 | 任务 | 关联 PLAN |
|----|----|------|----------|
| A1 | ✅ | 会话记忆 + 上下文智能裁剪 | PLAN-AI-001-1 (2026-06-15) |
| A2 | ✅ | API Key 安全存储 + 错误分级提示 | PLAN-AI-001-2 (2026-06-15) |
| A3 | ✅ | AI 任务能力扩展（reminders / rrule / update_task 字段补齐）+ NLP 实时预览 + 发送按钮反馈修复 | PLAN-AI-001-3 (2026-06-15) |
| A4 | ✅ | AI 时间安排优化助手（看当前任务 → 给优化建议 → 自动调整时间 / 自动拆解） | PLAN-AI-001-4 (2026-06-15) |
| A5a | ✅ | 聊天历史持久化（Isar 单会话）+ 欢迎语/AIService 加载竞态修复 | PLAN-AI-001-5 (2026-06-15) |
| A2b | ✅ | AI 设置保存失败修复 + Agent 字段更新语义（null 清空）+ 测试加固 | PLAN-AI-001-6 (2026-06-15) |
| A2c | ✅ | 修 macOS / iOS Keychain 写不进去 + 应用级 AES-GCM 加密兜底 | PLAN-AI-001-7 (2026-06-15) |

## 二、AI 功能改进（P1，下一批）

| ID | 状态 | 任务 | 备注 |
|----|----|------|----|
| A5 | ⬜ | 聊天历史多会话切换 UI（在 A5a 基础上） | 依赖 A5a 完成 |
| A6 | ⬜ | 新增 Action：query_tasks / bulk_update | 让 LLM 能搜全集 + 批量改 |
| A7 | ⬜ | 流式输出（SSE）+ 打字机效果 | 慢模型体验关键 |
| A8 | ⬜ | 逐项可编辑确认卡 | 单个 action 勾选 + 改参数 |
| A9 | ⬜ | 超时情绪支持专属入口 | 任务列表 ❤️ 按钮 |
| A10 | ✅ | AgentActionType.fromString 未知动作 → 不执行 + 提示（PLAN-AI-001-3 Phase C 已收，2026-06-15） | 修掉 fallback 到 createTask 的隐患 |
| A11 | ⬜ | AIService 单例化（Provider 化） | 准备流式/速率限制 |
| A12 | ⬜ | 思考型模型 reasoning_content 字段适配 | DeepSeek-R1 / o1 / Claude thinking |

## 三、AI 功能改进（P2，路线图）

| ID | 状态 | 任务 |
|----|----|------|
| A13 | ⬜ | 混合模式：原生 function calling + prompt 协议降级 |
| A14 | ⬜ | 多模态：图片附件 → vision 模型 → 自动抽任务 |
| A15 | ⬜ | 隐私脱敏开关（仅发 id / 哈希标题） |
| A16 | ⬜ | AI 周报 / 复盘自动推送 |
| A17 | ⬜ | 本地小模型 fallback（Gemma / Qwen-1.5B GGUF） |
| A18 | ⬜ | Anthropic / Gemini 原生 SDK；Cerebras / Groq Provider |

## 四、AI 之外的改进

### 数据 / 同步
- ⬜ B1：WebDAV 自动定时同步 + 网络恢复重试
- ⬜ B2：Android 14+ SCHEDULE_EXACT_ALARM 权限引导
- ⬜ B3：rrule 重复任务长期未开 App 时补全代际
- ⬜ B4：sync_history 增加变更日志

### 任务模型
- ⬜ B5：Task 加 parentId（子任务层级）
- ⬜ B6：Task 加 completedAt（完成时间）
- ⬜ B7：Task 加 estimatedMinutes（番茄/时间块基础）
- ⬜ B8：Task 加 附件 / 链接

### 视图 / 交互
- ⬜ B9：艾森豪威尔矩阵拖拽改象限
- ⬜ B10：日历月视图
- ⬜ B11：番茄钟 / 焦点模式

### 工程基础
- ⬜ B12：CI（GitHub Actions）
- ⬜ B13：Crash reporting
- ⬜ B14：i18n
- ⬜ B15：暗黑模式 / 动态主题色
- ⬜ B16：端到端集成测试
