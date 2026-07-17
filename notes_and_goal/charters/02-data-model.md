# Catodo 数据模型图

```mermaid
classDiagram
    class Task {
        +Id id
        +String? syncId
        +String title
        +String? description
        +bool isCompleted
        +int priority
        +DateTime? dueDate
        +List~String~ tags
        +String? groupName
        +String? rrule
        +bool isRepeatParent
        +DateTime createdAt
        +DateTime updatedAt
        +bool isDeleted
        +List~DateTime~ reminderTimes
        +copyWith() Task
    }

    class TaskFilter {
        +String? selectedGroup
        +int? selectedPriority
        +String? selectedTag
        +copyWith() TaskFilter
    }

    class ChatMessageEntity {
        +Id id
        +int sessionId
        +String role
        +String content
        +DateTime createdAt
        +bool visibleToModel
    }

    class ChatTurn {
        +String role
        +String content
        +toJson() Map
    }

    class SchedulingPlan {
        +String summary
        +List~SchedulingIssue~ issues
        +List~SchedulingSuggestion~ suggestions
        +List~String~ warnings
    }

    class SchedulingIssue {
        +String type
        +String? date
        +List~int~ taskIds
        +String note
    }

    class SchedulingSuggestion {
        +String id
        +SchedulingSuggestionType type
        +int? taskId
        +DateTime? newDueDate
        +int? priority
        +List~Map~? subtasks
        +List~DateTime~? reminderTimes
        +String reason
        +String title  "getter"
    }

    class AgentAction {
        +AgentActionType type
        +Map~String, dynamic~ params
        +bool needsConfirmation
        +String description
    }

    class AgentResponse {
        +String reply
        +List~AgentAction~ actions
        +List~String~ warnings
    }

    class WebDAVConfig {
        +String url
        +String username
        +String password
        +isValid  "getter: url+username+password"
    }

    Task --> TaskFilter : 被筛选
    Task --> AgentAction : 被创建/修改
    ChatMessageEntity --> ChatTurn : 映射为
    SchedulingPlan --> SchedulingSuggestion : 包含
    SchedulingPlan --> SchedulingIssue : 包含
    AgentResponse --> AgentAction : 包含
```

```mermaid
graph TD
    subgraph 枚举
        AT["AgentActionType<br/>create/update/complete/<br/>delete/decompose/<br/>addReminder/setRepeat/<br/>queryTasks/bulkUpdate<br/>+6 更多"]
        DM["DayViewMode<br/>all / focusToday / hideOverdue"]
        SS["SyncStatus<br/>idle / syncing / synced / failed"]
        SM["SyncMode<br/>autoMerge / localFirst / remoteFirst"]
        AE["AiErrorType<br/>unauthorized / network /<br/>parseFailed / rateLimited /<br/>+6 更多"]
        ST["SchedulingSuggestionType<br/>reschedule / decompose /<br/>setPriority / completeOrDrop /<br/>addReminder"]
        T["ThemeMode<br/>light / dark / system"]
    end
