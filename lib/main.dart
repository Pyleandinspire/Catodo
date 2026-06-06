import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:window_manager/window_manager.dart';
import 'ui/screens/task_list_screen.dart';
import 'ui/screens/eisenhower_screen.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/components/adaptive_navigation.dart';
import 'services/notification_service.dart';
import 'providers/isar_provider.dart';
import 'data/task_dao.dart';

/// 判断当前是否为桌面平台（Windows / macOS / Linux）
bool _isDesktopPlatform() {
  if (kIsWeb) return false;
  try {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  } catch (_) {
    return false;
  }
}

void main() {
  // 注册全局错误处理，防止原生层崩溃导致应用黑屏
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
  };

  // 捕获未处理的异步错误
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher Error: $error');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  // 配置系统 UI 样式（Android 15+ edge-to-edge 适配）
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 先启动 Flutter UI，避免异步初始化阻塞渲染
  runApp(const ProviderScope(child: CatodoApp()));

  // 桌面端窗口配置（仅桌面平台）
  if (_isDesktopPlatform()) {
    windowManager
        .ensureInitialized()
        .then((_) async {
          await windowManager.setMinimumSize(const Size(400, 600));
          await windowManager.setTitle('Catodo');
        })
        .catchError((_) {
          // 桌面窗口配置失败不影响运行
        });
  }

  // 异步初始化通知服务（不阻塞 UI 渲染）
  _initializeServices();
}

Future<void> _initializeServices() async {
  // 请求通知权限（Android 13+ 需要运行时权限）
  try {
    await Permission.notification.request();
  } catch (_) {
    // 权限请求失败不影响启动（旧版本 Android 或特殊设备）
  }

  // 初始化通知服务（内部有 try-catch 保护）
  // 使用 Future.microtask 确保在 main 完成后执行
  try {
    await NotificationService().initialize();
  } catch (_) {
    // 通知服务初始化失败不影响应用运行
  }
}

class CatodoApp extends StatefulWidget {
  const CatodoApp({super.key});

  @override
  State<CatodoApp> createState() => _CatodoAppState();
}

class _CatodoAppState extends State<CatodoApp> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    TaskListScreen(),
    EisenhowerScreen(),
    ChatScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _rescheduleReminders(dynamic isar) async {
    try {
      final dao = TaskDao(isar);
      final tasks = await dao.getAllTasks();
      final tasksWithReminders = tasks
          .where((task) => !task.isCompleted && task.reminderTimes.isNotEmpty)
          .toList();
      await NotificationService().rescheduleAllReminders(tasksWithReminders);
    } catch (e) {
      print('Failed to reschedule reminders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catodo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: Consumer(
        builder: (context, ref, child) {
          final isarAsync = ref.watch(isarProvider);
          return isarAsync.when(
            data: (isar) {
              _rescheduleReminders(isar);
              return AdaptiveNavigation(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                children: _screens,
              );
            },
            loading: () => const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在初始化数据库...'),
                  ],
                ),
              ),
            ),
            error: (error, stack) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('数据库初始化失败: $error'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
