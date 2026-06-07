# 阶段八开发笔记：DayView 视图与同步功能优化

## 写作日期

2026-06-07

## 一、开发目标

根据 `13_DayView和同步功能优化.md` 需求文档，实现以下三个功能模块：

1. **DayView 视图模式切换**：支持"全部"、"仅今日"、"隐藏过期"三种查看模式，已完成任务统一排到最底部
2. **完整数据导入导出**：新增 `.catodo` 格式，支持完整数据导出（含描述、标签、重复规则等 `.ics` 不支持的信息）
3. **WebDAV 同步优化**：支持 `.catodo` 格式同步，双格式兼容策略，增加同步模式选择（自动合并/本地优先/远程优先）

## 二、新增文件

### 2.1 `lib/providers/day_view_provider.dart`

DayView 查看模式的状态管理，持久化到 SharedPreferences。

```dart
enum DayViewMode { all, focusToday, hideOverdue }

class DayViewStateNotifier extends StateNotifier<DayViewMode> {
  static const _key = 'day_view_mode';

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

**设计要点**：
- 构造函数设为 `DayViewMode.all` 默认值，异步加载持久化值后更新 state
- `setMode` 同时更新内存状态和持久化存储
- 使用 `index.clamp` 防止存储值越界

### 2.2 `lib/services/catodo_io_service.dart`

`.catodo` 格式的导入导出服务，使用 JSON 格式，包含版本号管理。

**数据结构**：
```json
{
  "version": "1.0",
  "exportedAt": "2026-06-07T00:00:00.000Z",
  "appName": "Catodo",
  "tasks": [ ... ]
}
```

**关键方法**：
- `exportCatodo(tasks)` — 导出任务到 `.catodo` 文件
- `importCatodo(filePath)` — 从 `.catodo` 文件导入任务
- `validateVersion(version)` — 版本兼容性检查（主版本号必须一致）

**注意事项**：
- 导出时加密敏感字段（如 `password`），默认不导出 `settings`
- 导入时使用 `TaskDao.updateTask` 而非 `upsert`，确保通过 ID 正确匹配

## 三、修改文件

### 3.1 `lib/ui/screens/day_view_screen.dart`

**主要改动**：

1. **AppBar 头部整合**：将日期标题、左右箭头、视图模式按钮整合到 AppBar 中
2. **查看模式筛选**：
   - `all`：显示所有任务
   - `focusToday`：仅显示今日任务（截止日期 = 今天）
   - `hideOverdue`：隐藏过期任务（截止日期 < 今天 且未完成）
3. **排序逻辑**：已完成任务排在最后，其他按优先级排序
4. **过期判断**：使用 `DateTime(year, month, day)` 归一化比较，避免时分秒干扰

**关键排序代码**：
```dart
final sorted = [...filtered]
  ..sort((a, b) {
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1; // 已完成排最后
    }
    return (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099));
  });
```

### 3.2 `lib/ui/screens/data_management_screen.dart`

**添加的导入导出项**：
- 导出 `.catodo`（完整数据）
- 导入 `.catodo`（完整数据）

保留原有的 `.ics` 导入导出功能不变。

**DataIoActions 新增方法**：
- `importCatodo(context)` — 调用 `FilePicker` 选择文件后导入
- `exportCatodo(context)` — 生成 `.catodo` 文件并通过 `FileSaver` 保存

### 3.3 `lib/services/webdav_service.dart`

**核心改动**：

1. **新增 `SyncMode` 枚举**：
   ```dart
   enum SyncMode { autoMerge, localFirst, remoteFirst }
   ```

2. **新增 `SyncResult` 类**：包含合并后的任务列表、上下传计数等

3. **双格式读写策略**：
   - 同步时优先读写 `.catodo` 格式（远程文件名 `catodo_tasks.json`）
   - 同时保留 `.ics` 格式的读写能力（远程文件名 `tasks.ics`）
   - 两种格式用不同文件名，互不干扰

4. **`sync` 方法**：接受 `SyncMode` 参数，根据模式执行不同的合并策略
   - `autoMerge`：基于 `updatedAt` 时间戳，取较新版本
   - `localFirst`：冲突时保留本地版本
   - `remoteFirst`：冲突时使用远程版本

5. **`_resolveConflict` 方法**：统一的冲突解决逻辑

### 3.4 `lib/providers/webdav_provider.dart`

**新增 `SyncModeNotifier`**：
```dart
class SyncModeNotifier extends StateNotifier<SyncMode> {
  SyncModeNotifier() : super(SyncMode.autoMerge) { _loadMode(); }
  // ...
}

final syncModeProvider = StateNotifierProvider<SyncModeNotifier, SyncMode>((ref) {
  return SyncModeNotifier();
});
```

### 3.5 `lib/ui/screens/webdav_settings_screen.dart`

**新增同步模式选择 UI**：
- 使用 `RadioGroup<SyncMode>` + `RadioListTile` 实现模式选择
- 每个模式旁边有 `?` 按钮，点击弹出模式说明对话框
- 模式说明：
  - 自动合并：基于时间戳，冲突时取较新版本
  - 本地优先：冲突时以本地为准
  - 远程优先：冲突时以远程为准

**同步流程更新**：同步完成后将合并任务列表写回本地 Isar 数据库。

## 四、测试结果

- `flutter analyze`：0 错误，0 警告（新代码）
- `flutter test`：147/147 全部通过
- 所有原有功能不受影响

## 五、技术要点总结

| 要点 | 说明 |
|------|------|
| 日期比较 | 使用 `DateTime(year, month, day)` 归一化，避免时分秒干扰过期判断 |
| 已完成排序 | `a.isCompleted ? 1 : -1` 确保已完成任务始终排在最后 |
| 版本管理 | 主版本号必须一致，次版本号兼容 |
| 双格式策略 | 新格式用新文件名，旧格式保留读写，渐进式迁移 |
| 同步模式 | 三种模式覆盖不同使用场景，持久化到 SharedPreferences |
| RadioGroup | 使用新版 RadioGroup API 替代已弃用的 groupValue/onChanged |

## 六、文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/providers/day_view_provider.dart` | 新增 | DayView 查看模式状态管理 |
| `lib/services/catodo_io_service.dart` | 新增 | .catodo 格式导入导出 |
| `lib/ui/screens/day_view_screen.dart` | 修改 | 头部整合、筛选排序、模式切换 |
| `lib/ui/screens/data_management_screen.dart` | 修改 | 添加 .catodo 导入导出 |
| `lib/services/webdav_service.dart` | 修改 | SyncMode、SyncResult、双格式同步 |
| `lib/providers/webdav_provider.dart` | 修改 | 添加 SyncModeNotifier |
| `lib/ui/screens/webdav_settings_screen.dart` | 修改 | 同步模式选择 UI |