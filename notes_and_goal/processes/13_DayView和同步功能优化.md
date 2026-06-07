# Catodo 新功能开发步骤

## 开发分支

从 dev 分支创建新功能分支：

feats

---

## 功能一：按天视图UI改善和查看模式

### 1.1 需求分析

| 项                  | 需求                                                                 |
| ------------------- | -------------------------------------------------------------------- |
| 头部区域            | 标题、任务数、查看模式按钮全部整合到 AppBar 区域，紧凑一行           |
| 右上角              | 新增"查看模式"按钮（下拉菜单），设置持久化到 SharedPreferences       |
| 查看模式 - 全部     | 显示所有任务（默认），无截止日期任务也显示，**已完成任务统一排到最底部** |
| 查看模式 - 专注今日 | 只显示今天到期的任务，**不显示无截止日期的任务**    |
| 查看模式 - 隐藏过期 | 显示未过期 + 未来的任务，**已完成任务统一排到最底部（所有模式均适用）** |

### 1.2 技术实现方案

**文件结构**：

```
lib/
├── providers/
│   └── day_view_provider.dart     (新建)
└── ui/
    └── screens/
        └── day_view_screen.dart    (修改)
```

**day_view_provider.dart 设计**：

```dart
enum DayViewMode { all, focusToday, hideOverdue }

class DayViewStateNotifier extends StateNotifier<DayViewMode> {
  static const _key = 'day_view_mode';

  // 先初始化为默认值，异步加载后再更新 state
  DayViewStateNotifier() : super(DayViewMode.all) {
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    state = DayViewMode.values[index.clamp(0, DayViewMode.values.length - 1)];
  }

  Future<void> setMode(DayViewMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }
}
```

**持久化实现要点**：

- 使用 `SharedPreferences` 存储当前模式索引
- 初始化时先设默认值 `all`，异步加载后再更新（避免阻塞）
- `setMode` 时同时更新内存状态和持久化存储

**筛选与排序逻辑**：

```dart
// 按模式过滤（已完成任务不在此处过滤，统一保留到排序阶段）
List<Task> filteredTasks = tasks;

switch (mode) {
  case DayViewMode.all:
    // 不做额外过滤
    break;
  case DayViewMode.focusToday:
    final today = DateTime(now.year, now.month, now.day);
    filteredTasks = filteredTasks.where((t) {
      if (t.dueDate == null) return false; // 无截止日期不显示
      return DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day) == today;
    }).toList();
    break;
  case DayViewMode.hideOverdue:
    final today = DateTime(now.year, now.month, now.day);
    filteredTasks = filteredTasks.where((t) {
      if (t.dueDate == null) return true; // 无截止日期保留
      final dueDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return !dueDay.isBefore(today); // 不过期才显示
    }).toList();
    break;
}

// 排序：未完成任务在前，已完成任务排到最底部
filteredTasks.sort((a, b) {
  if (a.isCompleted && !b.isCompleted) return 1;
  if (!a.isCompleted && b.isCompleted) return -1;
  return 0; // 同类保持原有日期排序
});
```

**注意事项**：

- DateTime 比较必须裁掉时分秒，用 `DateTime(year, month, day)` 归一化
- 已完成任务**不隐藏**，统一排到列表最底部，按日期分组时同样适用

### 1.3 实现步骤

1. 创建 `day_view_provider.dart`（StateNotifier + SharedPreferences 持久化）
2. 修改 `day_view_screen.dart`：
   - 移除原有 header Padding 区域，将标题、任务数、模式按钮整合到 AppBar
   - AppBar title 改为 Row：左侧"按天视图 · N个任务"，右侧查看模式下拉按钮
   - 根据 `dayViewModeProvider` 过滤显示的任务
3. 测试验证

---

## 功能二：导入导出功能优化

### 2.1 需求分析

| 项           | 需求                                                                   |
| ------------ | ---------------------------------------------------------------------- |
| 新增完整格式 | 新增 Catodo 完整数据格式（.catodo）的导出/导入，**保留原有 .ics 导入导出不变** |
| 敏感信息控制 | 导出时提供"包含敏感设置"勾选项，**默认关闭**，不导出 WebDAV 密码、AI apiKey |
| WebDAV同步   | 改为使用新的完整格式进行同步                                           |

### 2.2 新数据格式设计

**文件名**：`*.catodo`（实际是 JSON 格式）

**结构**：

```json
{
  "version": "1.0",
  "exportedAt": "2026-06-07T10:30:00Z",
  "tasks": [...],
  "settings": {
    "webdav": {
      "url": "...",
      "username": "..."
    },
    "ai": {
      "provider": "...",
      "model": "..."
    }
  }
}
```

**敏感信息处理规则**：

- `webdav.password`：仅在用户勾选"包含敏感设置"时导出
- `ai.apiKey`：仅在用户勾选"包含敏感设置"时导出
- 导入时，敏感字段如果不存在则保留本地已有值，不做覆盖

**version 字段规则**：

- 导入时校验 version，不兼容的主版本号（如 2.x）拒绝导入并提示用户升级
- 当前支持版本：`1.x`

### 2.3 技术实现方案

**文件结构**：

```
lib/
├── services/
│   └── catodo_io_service.dart  (新建)
├── providers/
│   └── webdav_provider.dart    (修改)
└── ui/
    └── screens/
        └── data_management_screen.dart (修改)
```

### 2.4 实现步骤

1. 创建 `catodo_io_service.dart`：
   - `exportCatodo(tasks, settings, includeSensitive)`: 导出完整格式
   - `importCatodo(fileContent)`: 导入完整格式，**追加模式**（导入任务 id 重置，不与本地冲突）
   - `validateVersion(version)`: 版本校验
2. 修改 `data_management_screen.dart`：
   - 新增"完整格式导出"选项，弹出对话框含"包含敏感设置"勾选框（默认关闭）
   - 新增"完整格式导入"选项
   - 原有 .ics 导入导出保持不变
3. 修改 `webdav_service.dart`：
   - **新增** `.catodo` 格式文件（文件名 `catodo_full.catodo`），**保留**旧 `catodo_tasks.json` 格式读写不变
   - 读取策略：优先读新格式 `catodo_full.catodo`，不存在则回退读旧格式 `catodo_tasks.json`
   - 写入策略：同步时新旧格式都写，保证老版本客户端仍可读取
   - **WebDAV 同步仅同步 tasks，不同步 settings**（避免多设备间 webdav/AI 配置互相覆盖）

---

## 功能三：WebDAV同步模式选择

### 3.1 需求分析

| 项           | 需求                   |
| ------------ | ---------------------- |
| 同步模式选择 | 让用户可以选择同步模式 |

### 3.2 同步模式设计

**模式枚举**：

```dart
enum SyncMode {
  autoMerge,    // 自动合并（默认）
  localFirst,   // 本地优先
  remoteFirst,  // 远程优先
}
```

**各模式语义**：

| 模式        | 冲突时（同 id 双方都修改） | 本地独有任务 | 远程独有任务 | 软删除处理                     |
| ----------- | -------------------------- | ------------ | ------------ | ------------------------------ |
| autoMerge   | updatedAt 新的胜出         | 保留         | 保留         | 双方都标记 isDeleted 才真删除  |
| localFirst  | 本地胜出                   | 保留         | 保留         | 双方都标记 isDeleted 才真删除  |
| remoteFirst | 远程胜出                   | 保留         | 保留         | 双方都标记 isDeleted 才真删除  |

**软删除合并规则（所有模式统一）**：

- 一方 `isDeleted=true`、另一方 `isDeleted=false` → 保留未删除版本
- 双方 `isDeleted=true` → 真删除（不保留）
- 双方 `isDeleted=false` → 按各自模式处理冲突

**UI 说明**：

- 每个同步模式选项后面附带一个 `?` 图标按钮，点击弹出该模式的说明文字

### 3.3 技术实现方案

**文件结构**：

```
lib/
├── providers/
│   └── webdav_provider.dart    (修改)
├── ui/
│   └── screens/
│       └── webdav_settings_screen.dart (修改)
└── services/
    └── webdav_service.dart     (修改)
```

### 3.4 实现步骤

1. 修改 `webdav_provider.dart`：
   - 添加 `syncMode` 状态管理（StateNotifier）
   - 持久化 syncMode 到 SharedPreferences
2. 修改 `webdav_settings_screen.dart`：
   - 添加同步模式选择区域（下拉菜单或 RadioListTile）
   - 每个模式选项后加 `?` 图标按钮，点击弹出说明弹窗
3. 修改 `webdav_service.dart`：
   - `sync()` 方法接受 `mode` 参数
   - 实现各模式的合并逻辑（按上表语义）

---

## 开发任务清单

| 阶段   | 任务                                   | 优先级 | 状态 |
| ------ | -------------------------------------- | ------ | ---- |
| 功能一 | 创建 day_view_provider.dart            | P0     | 待做 |
| 功能一 | 修改 day_view_screen.dart 布局         | P0     | 待做 |
| 功能一 | 添加查看模式按钮和筛选逻辑             | P0     | 待做 |
| 功能二 | 创建 catodo_io_service.dart            | P0     | 待做 |
| 功能二 | 修改数据管理页面 UI（含敏感信息勾选）  | P0     | 待做 |
| 功能二 | 修改 WebDAV 同步使用新格式             | P0     | 待做 |
| 功能三 | 添加 syncMode 到 WebDAV Provider       | P1     | 待做 |
| 功能三 | WebDAV 设置页添加模式选择 + 说明按钮   | P1     | 待做 |
| 功能三 | 实现各同步模式的合并逻辑               | P1     | 待做 |
| 测试   | 功能一测试                             | P0     | 待做 |
| 测试   | 功能二测试                             | P0     | 待做 |
| 测试   | 功能三测试                             | P1     | 待做 |

---

## 测试用例设计

### 功能一测试

```dart
testWidgets('Day view focus today mode', (tester) async {
  // 设置模式为 focusToday
  // 创建一个昨天、一个今天、一个明天、一个无截止日期的任务
  // 验证只显示今天的任务（无截止日期不显示）
});

testWidgets('Day view hide overdue mode', (tester) async {
  // 设置模式为 hideOverdue
  // 创建一个过期任务、一个非过期任务、一个已完成任务
  // 验证显示非过期任务，已完成任务排在最底部
});

testWidgets('Day view all mode completed tasks at bottom', (tester) async {
  // 设置模式为 all
  // 创建已完成和未完成任务
  // 验证所有模式下已完成任务都排在最底部
});
```

### 功能二测试

```dart
test('Export/import catodo format without sensitive data', () async {
  // 创建测试任务和设置
  // 导出为 .catodo（includeSensitive=false）
  // 验证导出内容不含 password 和 apiKey
  // 删除本地任务
  // 导入
  // 验证任务完整恢复（id 已重置）
});

test('Export catodo with sensitive data', () async {
  // 导出时 includeSensitive=true
  // 验证导出内容包含 password 和 apiKey
});

test('Import catodo rejects incompatible version', () async {
  // 构造 version: "2.0" 的数据
  // 验证导入被拒绝并提示
});
```

### 功能三测试

```dart
test('Sync autoMerge mode', () async {
  // 本地有任务 A(updatedAt 新)、任务 B(本地独有)
  // 远程有任务 A(updatedAt 旧)、任务 C(远程独有)
  // 验证：A 取本地、B 保留、C 保留
});

test('Sync localFirst mode', () async {
  // 本地有任务 A(updatedAt 旧)、任务 B(本地独有)
  // 远程有任务 A(updatedAt 新)、任务 C(远程独有)
  // 验证：A 取本地、B 保留、C 保留
});

test('Sync remoteFirst mode', () async {
  // 本地有任务 A(updatedAt 新)、任务 B(本地独有)
  // 远程有任务 A(updatedAt 旧)、任务 C(远程独有)
  // 验证：A 取远程、B 保留、C 保留
});

test('Sync soft delete handling', () async {
  // 本地 isDeleted=true、远程 isDeleted=false → 保留远程（未删除）
  // 本地 isDeleted=true、远程 isDeleted=true → 真删除
  // 本地 isDeleted=false、远程 isDeleted=false → 按模式处理
});
```

---


## 开发注意事项

1. **保持向后兼容**：原有 .ics 导入导出、旧 WebDAV 格式读写均保留不动
2. **UI 响应式适配小屏手机**
3. **同步操作需要错误处理和重试逻辑**
4. **所有修改需要通过现有测试**
5. **DateTime 比较统一裁掉时分秒**，用 `DateTime(year, month, day)` 归一化
6. **WebDAV 同步仅同步 tasks**，settings 仅用于本地导入导出备份
7. **导入 catodo 格式为追加模式**，任务 id 重置，避免覆盖本地数据
8. **已完成任务不隐藏**，统一排到列表最底部
