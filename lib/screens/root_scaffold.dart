import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/triad.dart';
import '../services/auth_service.dart';
import '../services/ring_service.dart';
import '../services/triad_service.dart';
import '../widgets/phone_prompt_banner.dart';
import '../widgets/update_banner.dart';
import 'account_screen.dart';
import 'home_screen.dart';
import 'reading_screen.dart';
import 'shared_meeting_screen.dart';

/// Корневой экран: разделы QT / Чтение / Тройка + обработка входящего звонка
/// (звук и окно «Ответить», когда кто-то из тройки начинает звонок в
/// назначенное расписанием время).
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  static const _screens = [HomeScreen(), ReadingScreen(), AccountScreen()];

  // Человек может быть в нескольких тройках — следим за звонком каждой
  // отдельно: звонки не смешиваются, у каждой тройки свой канал.
  StreamSubscription<List<Triad>>? _triadsSub;
  final Map<String, StreamSubscription<Map<String, dynamic>?>> _callSubs = {};
  final Map<String, Triad> _triads = {};
  final Map<String, bool> _prevActive = {};
  bool _showingIncoming = false;
  String? _incomingTriadId; // чей звонок сейчас звенит

  @override
  void initState() {
    super.initState();
    _triadsSub = TriadService.instance.myTriadsStream().listen(_onTriads);
  }

  @override
  void dispose() {
    _triadsSub?.cancel();
    for (final s in _callSubs.values) {
      s.cancel();
    }
    RingService.instance.stop();
    super.dispose();
  }

  void _onTriads(List<Triad> triads) {
    _triads
      ..clear()
      ..addEntries(triads.map((t) => MapEntry(t.id, t)));
    final ids = _triads.keys.toSet();
    // Отписаться от троек, из которых вышли.
    for (final id in _callSubs.keys.toList()) {
      if (!ids.contains(id)) {
        _callSubs.remove(id)?.cancel();
        _prevActive.remove(id);
      }
    }
    // Подписаться на новые.
    for (final t in triads) {
      _callSubs.putIfAbsent(t.id, () {
        _prevActive[t.id] = false;
        return TriadService.instance
            .callStateStream(t.id)
            .listen((s) => _onCallState(t.id, s));
      });
    }
  }

  void _onCallState(String triadId, Map<String, dynamic>? state) {
    if (kIsWeb) return; // в вебе звонков нет
    final active = (state?['active'] as bool?) ?? false;
    final startedBy = state?['startedBy'] as String?;
    final myUid = AuthService.instance.uid;
    final triad = _triads[triadId];

    if (active &&
        !(_prevActive[triadId] ?? false) &&
        startedBy != myUid &&
        !_showingIncoming &&
        TriadService.isWithinSchedule(triad?.callSchedule, DateTime.now())) {
      _showIncoming(triad);
    }
    // Завершение звонка гасит звонок только СВОЕЙ тройки: событие «не активен»
    // из другой тройки не должно обрывать звенящий вызов.
    if (!active && _incomingTriadId == triadId) {
      RingService.instance.stop();
      if (_showingIncoming && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showingIncoming = false;
      }
      _incomingTriadId = null;
    }
    _prevActive[triadId] = active;
  }

  Future<void> _showIncoming(Triad? triad) async {
    if (triad == null || !mounted) return;
    _showingIncoming = true;
    _incomingTriadId = triad.id;
    RingService.instance.start();

    final answer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.call, size: 40),
        title: const Text('Входящий звонок'),
        content: const Text('Участник тройки начал звонок. Подключиться?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отклонить')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ответить')),
        ],
      ),
    );

    _showingIncoming = false;
    _incomingTriadId = null;
    await RingService.instance.stop();
    if (answer == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SharedMeetingScreen(triad: triad, autoJoin: true)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const UpdateBanner(),
          const PhonePromptBanner(),
          Expanded(child: IndexedStack(index: _index, children: _screens)),
        ],
      ),
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
