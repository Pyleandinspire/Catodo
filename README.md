**[English](README.md)** | [中文](README.zh-CN.md) | [日本語](README.ja.md) | [Deutsch](README.de.md)

---

# Catodo

A cross-platform task management app built with Flutter. Manage your to-dos with smart views, AI-powered assistance, and seamless cross-device sync via WebDAV.

## Features

- **Task Management** - Create, edit, complete, and delete tasks with priorities, tags, groups, due dates, and multiple reminders
- **Smart Views** - List view, day view (focus today / hide overdue), and Eisenhower Matrix for priority-based organization
- **Recurring Tasks** - Set daily, weekly, or monthly repeat rules; next instance auto-generates on completion
- **WebDAV Sync** - Incremental cross-device sync with three conflict-resolution modes (auto-merge, local-first, remote-first) and soft-delete propagation
- **AI Assistant** - Chat with an LLM agent to create, update, decompose, and manage tasks through natural language
- **Data Import/Export** - `.ics` calendar format and `.catodo` full-backup format (with optional sensitive settings)
- **Local Notifications** - Scheduled reminders that persist across app restarts
- **Multi-Platform** - Android, iOS, Windows, macOS, Linux, and Web

## Installation

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.12.0
- Dart SDK >= 3.12.0
- For Android: Android SDK with minSdkVersion 21+
- For iOS: Xcode 15+, CocoaPods
- For Desktop: corresponding platform build tools

### Build from Source

```bash
# Clone the repository
git clone https://github.com/your-username/catodo.git
cd catodo

# Install dependencies
flutter pub get

# Generate Isar schemas
dart run build_runner build --delete-conflicting-outputs

# Run on connected device or emulator
flutter run
```

### Build Release

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

## Usage

### Task Management

| Action          | How                                                                          |
| --------------- | ---------------------------------------------------------------------------- |
| Create a task   | Tap the **+** button on the bottom bar, fill in the form, tap **Save**       |
| Edit a task     | Tap any task card to open the editor                                         |
| Complete a task | Tap the circle checkbox on the task card                                     |
| Delete a task   | Open the task editor, scroll to bottom, tap **Delete Task**, confirm         |
| Set priority    | In the task form, choose None / Low / Medium / High                          |
| Set reminder    | In the task form, tap **Add Reminder**, pick date and time                   |
| Set repeat      | Toggle **Repeat Task** in the form, choose daily/weekly/monthly and interval |

### Views

- **List View** (default) - All active tasks with group and tag filters
- **Day View** - Tasks grouped by due date; switch between All / Focus Today / Hide Overdue
- **Eisenhower Matrix** - Four-quadrant view based on urgency and importance (priority)

### WebDAV Sync

1. Go to **Settings > WebDAV Sync**
2. Enter your WebDAV server URL, username, and password
3. Tap **Test Connection** to verify
4. Tap **Save Config**
5. Choose a sync mode:
   - **Auto Merge** (default) - Conflicts resolved by newest `updatedAt`
   - **Local First** - Conflicts favor local version
   - **Remote First** - Conflicts favor remote version
6. Tap **Start Sync**

### AI Assistant

1. Go to **Settings > AI Assistant** and configure your LLM provider (OpenAI, DeepSeek, Doubao, GLM, Qwen, Kimi, or custom endpoint)
2. Enter your API key and model name, then tap **Save Config**
3. Navigate to the **AI** tab in the bottom navigation
4. Chat naturally - the AI agent can create tasks, decompose them, add tags, set priorities, and more
5. Low-risk actions (create, tag, group, priority) execute automatically; high-risk actions (update, complete, delete) require your confirmation

### Data Import/Export

Go to **Settings > Data Management**:

| Action | Format    | Description                                                         |
| ------ | --------- | ------------------------------------------------------------------- |
| Import | `.ics`    | Import tasks from calendar files                                    |
| Import | `.catodo` | Restore from a full Catodo backup                                   |
| Export | `.ics`    | Export active tasks as a calendar file                              |
| Export | `.catodo` | Export all tasks and settings (optionally including sensitive data) |

## Configuration

### AI Provider Settings

Stored in `SharedPreferences`:

| Key              | Description                                                                       |
| ---------------- | --------------------------------------------------------------------------------- |
| `ai_provider_id` | Provider ID (`openai`, `deepseek`, `doubao`, `glm`, `qwen`, `moonshot`, `custom`) |
| `ai_api_url`     | API endpoint URL                                                                  |
| `ai_api_key`     | API key                                                                           |
| `ai_model`       | Model name                                                                        |

### WebDAV Settings

Stored in `SharedPreferences`:

| Key               | Description                                                         |
| ----------------- | ------------------------------------------------------------------- |
| `webdav_url`      | WebDAV server URL                                                   |
| `webdav_username` | Username                                                            |
| `webdav_password` | Password                                                            |
| `sync_mode`       | Conflict resolution mode (`autoMerge`, `localFirst`, `remoteFirst`) |

### Day View Settings

| Key             | Description                                      |
| --------------- | ------------------------------------------------ |
| `day_view_mode` | View filter (`all`, `focusToday`, `hideOverdue`) |

## Project Structure

```
lib/
├── main.dart                    # App entry, navigation, reminder scheduling
├── models/
│   ├── task.dart                # Task model (Isar Collection)
│   └── filter.dart              # TaskFilter model
├── data/
│   └── task_dao.dart            # Data access object
├── services/
│   ├── database_service.dart    # Isar singleton management
│   ├── webdav_service.dart      # WebDAV sync service
│   ├── ai_service.dart          # AI API client
│   ├── ai_agent.dart            # AI agent actions & execution
│   ├── nlp_service.dart         # Natural language parsing
│   ├── ics_service.dart         # ICS file parsing & generation
│   ├── catodo_io_service.dart   # .catodo format import/export
│   ├── notification_service.dart # Notification service (conditional export)
│   ├── repeat_task_service.dart  # Recurring task generation
│   └── llm_provider_registry.dart # LLM provider definitions
├── providers/
│   ├── isar_provider.dart       # Isar instance provider
│   ├── task_providers.dart      # Task-related providers
│   ├── webdav_provider.dart     # WebDAV config & sync mode
│   └── day_view_provider.dart   # Day view mode
└── ui/
    ├── screens/                 # Page widgets
    └── components/              # Reusable UI components
```

## Development

### Run Tests

```bash
# Unit tests
flutter test

# Static analysis
flutter analyze

# Generate Isar schemas after model changes
dart run build_runner build --delete-conflicting-outputs
```

### Architecture

The app follows a layered architecture:

```
UI Layer (screens, components)
    ↓
State Management Layer (Riverpod providers)
    ↓
Service Layer (WebDAV, AI, notifications, etc.)
    ↓
Data Layer (TaskDao, Isar database)
```

## Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/your-feature-name`
3. **Commit** your changes with clear, descriptive messages
4. **Test** your changes: run `flutter test` and `flutter analyze`
5. **Push** to your fork: `git push origin feature/your-feature-name`
6. **Open** a Pull Request against the `main` branch

### Guidelines

- Follow the existing code style and project structure
- Add tests for new functionality
- Keep PRs focused on a single concern
- Document public APIs and complex logic
- Ensure `flutter analyze` passes with no warnings

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Contact

- **Project Maintainer**: [Open an issue](https://github.com/your-username/catodo/issues)
- **Bug Reports**: [GitHub Issues](https://github.com/your-username/catodo/issues)
- **Feature Requests**: [GitHub Issues](https://github.com/your-username/catodo/issues)
