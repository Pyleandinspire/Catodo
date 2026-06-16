import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:window_manager/window_manager.dart';
import 'package:isar/isar.dart';
import 'ui/screens/task_list_screen.dart';
import 'ui/screens/eisenhower_screen.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/components/adaptive_navigation.dart';
import 'services/notification_service.dart';
import 'services/secrets_migration.dart';
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
          await windowManager.setTitle('喵待办');
        })
        .catchError((_) {
          // 桌面窗口配置失败不影响运行
        });
  }

  // 异步初始化通知服务（不阻塞 UI 渲染）
  _initializeServices();
}

Future<void> _initializeServices() async {
  // 一次性迁移旧 SP 明文凭据到 SecureStore（失败也不阻塞启动）
  await migrateLegacySecretsIfNeeded();

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

ThemeData _buildAppTheme() {
  const seedColor = Color(0xFF5B6CFF);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF7F8FC),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colorScheme.surface,
      selectedIconTheme: IconThemeData(color: colorScheme.primary),
      selectedLabelTextStyle: TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
      unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      unselectedLabelTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      indicatorColor: colorScheme.primaryContainer,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

class CatodoApp extends ConsumerStatefulWidget {
  const CatodoApp({super.key});

  @override
  ConsumerState<CatodoApp> createState() => _CatodoAppState();
}

class _CatodoAppState extends ConsumerState<CatodoApp> {
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

  void _rescheduleReminders(Isar isar) async {
    try {
      final dao = TaskDao(isar);
      final tasks = await dao.getAllTasks();
      final tasksWithReminders = tasks
          .where((task) => !task.isCompleted && task.reminderTimes.isNotEmpty)
          .toList();
      await NotificationService().rescheduleAllReminders(tasksWithReminders);
    } catch (e) {
      debugPrint('Failed to reschedule reminders: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // 监听 isarProvider 就绪后调度提醒（仅执行一次）
    ref.listenManual(isarProvider, (prev, next) {
      next.whenData((isar) => _rescheduleReminders(isar));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '喵待办',
      theme: _buildAppTheme(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Consumer(
        builder: (context, ref, child) {
          final isarAsync = ref.watch(isarProvider);
          return isarAsync.when(
            data: (isar) {
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
