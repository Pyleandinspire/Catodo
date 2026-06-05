import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/screens/task_list_screen.dart';
import 'ui/screens/day_view_screen.dart';
import 'ui/screens/eisenhower_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'providers/isar_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  runApp(const ProviderScope(child: CatodoApp()));
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
    DayViewScreen(),
    EisenhowerScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catodo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Consumer(
        builder: (context, ref, child) {
          final isarAsync = ref.watch(isarProvider);
          return isarAsync.when(
            data: (_) => Scaffold(
              body: _screens[_selectedIndex],
              bottomNavigationBar: BottomNavigationBar(
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.list),
                    label: '待办',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_today),
                    label: '按天',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.grid_3x3),
                    label: '矩阵',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings),
                    label: '设置',
                  ),
                ],
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
              ),
            ),
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