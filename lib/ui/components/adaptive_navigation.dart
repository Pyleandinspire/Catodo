import 'package:flutter/material.dart';

/// 自适应导航组件：窄屏使用 BottomNavigationBar，宽屏使用 NavigationRail。
class AdaptiveNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> children;

  const AdaptiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.children,
  });

  static const _navItems = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.list),
      label: 'to-do',
    ),
    NavigationDestination(
      icon: Icon(Icons.grid_3x3),
      label: 'priority',
    ),
    NavigationDestination(
      icon: Icon(Icons.message),
      label: 'chatting',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings),
      label: 'setting',
    ),
  ];

  static const _railDestinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.list),
      label: Text('to-do'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.grid_3x3),
      label: Text('priority'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.message),
      label: Text('chatting'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings),
      label: Text('setting'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  destinations: _railDestinations,
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: children[selectedIndex]),
              ],
            ),
          );
        }

        return Scaffold(
          body: children[selectedIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: _navItems,
          ),
        );
      },
    );
  }
}