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

  StreamSubscription<Triad?>? _triadSub;
  StreamSubscription<Map<String, dynamic>?>? _callSub;
  Triad? _triad;
  String? _watchedTriadId;
  bool _prevActive = false;
  bool _showingIncoming = false;

  @override
  void initState() {
    super.initState();
    _triadSub = TriadService.instance.myTriadStream().listen(_onTriad);
  }

  @override
  void dispose() {
    _triadSub?.cancel();
    _callSub?.cancel();
    RingService.instance.stop();
    super.dispose();
  }

  void _onTriad(Triad? triad) {
    _triad = triad;
    if (triad?.id != _watchedTriadId) {
      _callSub?.cancel();
      _watchedTriadId = triad?.id;
      _prevActive = false;
      if (triad != null) {
        _callSub = TriadService.instance
            .callStateStream(triad.id)
            .listen(_onCallState);
      }
    }
  }

  void _onCallState(Map<String, dynamic>? state) {
    if (kIsWeb) return; // в вебе звонков нет
    final active = (state?['active'] as bool?) ?? false;
    final startedBy = state?['startedBy'] as String?;
    final myUid = AuthService.instance.uid;

    if (active &&
        !_prevActive &&
        startedBy != myUid &&
        !_showingIncoming &&
        TriadService.isWithinSchedule(_triad?.callSchedule, DateTime.now())) {
      _showIncoming();
    }
    if (!active) {
      RingService.instance.stop();
      if (_showingIncoming && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showingIncoming = false;
      }
    }
    _prevActive = active;
  }

  Future<void> _showIncoming() async {
    final triad = _triad;
    if (triad == null || !mounted) return;
    _showingIncoming = true;
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
