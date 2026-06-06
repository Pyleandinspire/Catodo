# Catodo 新功能开发步骤

## 开发分支

从 dev 分支创建新功能分支：

```bash
git checkout -b feature/dayview-and-sync
```

---

## 功能一：按天视图UI改善和查看模式

### 1.1 需求分析

| 项                  | 需求                                        |
| ------------------- | ------------------------------------------- |
| 左上角              | 显示按天视图和任务数，缩小尺寸              |
| 右上角              | 新增"查看模式"按钮,并且要把保存的设置持久化 |
| 查看模式 - 专注今日 | 只显示今天的任务                            |
| 查看模式 - 隐藏过期 | 显示除了overdue的任务                       |

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
  final SharedPreferences _prefs;
  static const _key = 'day_view_mode';

  DayViewStateNotifier(this._prefs)
      : super(_loadMode(_prefs));

  static DayViewMode _loadMode(SharedPreferences prefs) {
    final index = prefs.getInt(_key) ?? 0;
    return DayViewMode.values[index.clamp(0, DayViewMode.values.length - 1)];
  }

  void setMode(DayViewMode mode) {
    state = mode;
    _prefs.setInt(_key, mode.index);
  }
}
```

**持久化实现要点**：

- 使用 `SharedPreferences` 存储当前模式索引
- 初始化时从本地读取，默认为 `all`
- `setMode` 时同时更新内存状态和持久化存储

### 1.3 实现步骤

1. 创建 `day_view_provider.dart`
2. 修改 `day_view_screen.dart`：
   - 调整左上角布局（缩小尺寸）
   - 添加右上角"查看模式"按钮（下拉菜单）
   - 根据当前 mode 过滤显示的任务
3. 添加筛选逻辑：
   - focusToday: `task.dueDate == today`
   - hideOverdue: `!task.isOverdue`
4. 测试验证

---

## 功能二：导入导出功能优化

### 2.1 需求分析

| 项           | 需求                                                        |
| ------------ | ----------------------------------------------------------- |
| 新增完整格式 | 不是仅 .ics，而是完整的 Catodo 数据格式（.catodo 或 .json） |
| WebDAV同步   | 改为使用新的完整格式进行同步                                |

### 2.2 新数据格式设计

**文件名**：`*.catodo`（实际是 JSON 格式）

**结构**：

```json
{
  "version": "1.0",
  "exportedAt": "2026-06-07T10:30:00Z",
  "tasks": [...],
  "settings": {
    "webdav": {...},
    "ai": {...}
  }
}
```

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
   - `exportTasks()`: 导出完整格式
   - `importTasks()`: 导入完整格式
2. 修改 `data_management_screen.dart`：
   - 新增"完整格式导出"选项
   - 新增"完整格式导入"选项
3. 修改 `webdav_service.dart`：
   - 同步时改为使用新的完整格式
   - 向后兼容（兼容旧格式）

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
  manual        // 手动选择
}
```

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
   - 添加 `syncMode` 状态管理
   - 持久化 syncMode 到 SharedPreferences
2. 修改 `webdav_settings_screen.dart`：
   - 添加同步模式选择下拉菜单
3. 修改 `webdav_service.dart`：
   - `sync()` 方法接受 `mode` 参数
   - 实现各模式的逻辑

---

## 开发任务清单

| 阶段   | 任务                             | 优先级 | 状态 |
| ------ | -------------------------------- | ------ | ---- |
| 功能一 | 创建 day_view_provider.dart      | P0     | 待做 |
| 功能一 | 修改 day_view_screen.dart 布局   | P0     | 待做 |
| 功能一 | 添加查看模式按钮和逻辑           | P0     | 待做 |
| 功能二 | 创建 catodo_io_service.dart      | P0     | 待做 |
| 功能二 | 修改数据管理页面 UI              | P0     | 待做 |
| 功能二 | 修改 WebDAV 同步使用新格式       | P0     | 待做 |
| 功能三 | 添加 syncMode 到 WebDAV Provider | P1     | 待做 |
| 功能三 | WebDAV 设置页添加模式选择        | P1     | 待做 |
| 功能三 | 实现各同步模式的逻辑             | P1     | 待做 |
| 测试   | 功能一测试                       | P0     | 待做 |
| 测试   | 功能二测试                       | P0     | 待做 |
| 测试   | 功能三测试                       | P1     | 待做 |

---

## 测试用例设计

### 功能一测试

```dart
testWidgets('Day view focus today mode', (tester) async {
  // 设置模式为 focusToday
  // 创建一个昨天、一个今天、一个明天的任务
  // 验证只显示今天的任务
});

testWidgets('Day view hide overdue mode', (tester) async {
  // 设置模式为 hideOverdue
  // 创建一个过期任务和一个非过期任务
  // 验证只显示非过期任务
});
```

### 功能二测试

```dart
test('Export/import catodo format', () async {
  // 创建一些测试任务
  // 导出为 .catodo 格式
  // 删除本地任务
  // 导入
  // 验证任务完整恢复
});
```

### 功能三测试

```dart
test('Sync modes behavior', () async {
  // 本地和远程都有任务
  // 测试不同模式的合并结果
});
```

---

## Git 提交建议

| 提交阶段     | 提交信息                                |
| ------------ | --------------------------------------- |
| 功能一基础   | feat: 添加 day view provider 和 UI 调整 |
| 功能一完成   | feat: 实现 day view 查看模式功能        |
| 功能二基础   | feat: 添加 catodo 完整格式导入导出      |
| 功能二WebDAV | refactor: WebDAV 同步使用 catodo 格式   |
| 功能三完成   | feat: 实现 WebDAV 同步模式选择          |
| 最终测试     | test: 添加新功能测试用例                |

---

## 开发注意事项

1. 保持向后兼容
2. UI 响应式适配小屏手机
3. 同步操作需要错误处理和重试逻辑
4. 所有修改需要通过现有测试
