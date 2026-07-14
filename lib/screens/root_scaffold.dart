import 'package:flutter/material.dart';

import 'account_screen.dart';
import 'home_screen.dart';
import 'reading_screen.dart';

/// Корневой экран с переключением между разделами:
/// «QT (Тихое время)» и «Ежедневное чтение».
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  static const _screens = [HomeScreen(), ReadingScreen(), AccountScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism_outlined),
            selectedIcon: Icon(Icons.volunteer_activism),
            label: 'QT',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Чтение',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Тройка',
          ),
        ],
      ),
    );
  }
}
