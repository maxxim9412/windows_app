import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_token_service/agora_token_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../agora_config.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';
import '../models/triad.dart';
import '../services/triad_service.dart';
import '../utils/date_helpers.dart';
import '../utils/note_questions.dart';

/// Совместная встреча тройки: встроенный аудиозвонок (Agora) + синхронно
/// показываемая заметка. У всех троих открыта одна и та же заметка; любой
/// может показать свою или переключить на чужую.
class SharedMeetingScreen extends StatefulWidget {
  final Triad triad;
  const SharedMeetingScreen({super.key, required this.triad});

  @override
  State<SharedMeetingScreen> createState() => _SharedMeetingScreenState();
}

class _SharedMeetingScreenState extends State<SharedMeetingScreen> {
  DateTime _date = dateOnly(DateTime.now());

  RtcEngine? _engine;
  bool _inCall = false;
  bool _joining = false;
  bool _muted = false;
  final Set<int> _remoteUids = {};

  Triad get triad => widget.triad;

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  // --- Звонок -------------------------------------------------------------

  Future<void> _joinCall() async {
    if (_joining || _inCall || _engine != null) return; // защита от двойного входа
    if (kAgoraAppId.isEmpty) {
      _snack('Аудиозвонок не настроен: не задан App ID Agora (см. lib/agora_config.dart).');
      return;
    }
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _snack('Нужен доступ к микрофону для звонка.');
      return;
    }

    setState(() => _joining = true);
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(const RtcEngineContext(appId: kAgoraAppId));
      await engine.enableAudio();
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) {
          debugPrint('[call] onJoinChannelSuccess channel=${conn.channelId}');
          if (mounted) {
            setState(() {
              _inCall = true;
              _joining = false;
            });
          }
        },
        onUserJoined: (conn, remoteUid, elapsed) {
          debugPrint('[call] onUserJoined $remoteUid');
          if (mounted) setState(() => _remoteUids.add(remoteUid));
        },
        onUserOffline: (conn, remoteUid, reason) {
          if (mounted) setState(() => _remoteUids.remove(remoteUid));
        },
        onError: (err, msg) {
          debugPrint('[call] onError $err $msg');
          if (mounted && !_inCall) {
            setState(() => _joining = false);
            _snack('Ошибка звонка: $err ${msg.isNotEmpty ? '($msg)' : ''}');
          }
        },
      ));
      // Если у проекta включён App Certificate — генерируем токен, иначе пусто.
      final token = kAgoraAppCertificate.isEmpty
          ? ''
          : RtcTokenBuilder.build(
              appId: kAgoraAppId,
              appCertificate: kAgoraAppCertificate,
              channelName: triad.id,
              uid: '0',
              role: RtcRole.publisher,
              expireTimestamp:
                  DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/
                      1000,
            );
      await engine.joinChannel(
        token: token,
        channelId: triad.id,
        uid: 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
      _engine = engine;

      // Если за 12 сек не подключились — вероятно, нужен токен (включён App
      // Certificate) или нет сети.
      Future.delayed(const Duration(seconds: 12), () {
        if (mounted && _joining && !_inCall) {
          setState(() => _joining = false);
          _snack('Не удалось подключиться. Возможно, у проекта Agora включён '
              'App Certificate (нужен токен).');
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _joining = false);
        _snack('Не удалось начать звонок: $e');
      }
    }
  }

  Future<void> _leaveCall() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    if (mounted) {
      setState(() {
        _inCall = false;
        _muted = false;
        _remoteUids.clear();
      });
    }
  }

  Future<void> _toggleMute() async {
    final m = !_muted;
    await _engine?.muteLocalAudioStream(m);
    if (mounted) setState(() => _muted = m);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  // --- Показ заметки ------------------------------------------------------

  Future<void> _present(String ownerUid) async {
    await TriadService.instance.presentNote(triad.id, ownerUid, dateKey(_date));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Совместная встреча')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _callCard(theme),
          const Divider(height: 32),

          Row(
            children: [
              Text('День:', style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Expanded(child: Text(humanDateShort(_date))),
              TextButton(onPressed: _pickDate, child: const Text('Изменить')),
            ],
          ),
          const SizedBox(height: 8),
          Text('Показать заметку участника:', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _presenterChips(theme),
          const Divider(height: 32),

          _sharedNote(theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _callCard(ThemeData theme) {
    if (_joining) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Подключаюсь к звонку…'),
          ]),
        ),
      );
    }
    if (!_inCall) {
      return FilledButton.icon(
        onPressed: _joinCall,
        icon: const Icon(Icons.call),
        label: const Text('Присоединиться к звонку'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      );
    }
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.call, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _remoteUids.isEmpty
                    ? 'В звонке. Ждём собеседников…'
                    : 'В звонке • собеседников: ${_remoteUids.length}',
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: _muted ? 'Включить микрофон' : 'Выключить микрофон',
              onPressed: _toggleMute,
              icon: Icon(_muted ? Icons.mic_off : Icons.mic),
            ),
            IconButton(
              tooltip: 'Выйти из звонка',
              onPressed: _leaveCall,
              icon: Icon(Icons.call_end, color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presenterChips(ThemeData theme) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: TriadService.instance.sharedSessionStream(triad.id),
      builder: (context, snap) {
        final currentOwner = snap.data?['ownerUid'] as String?;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: triad.memberUids.map((uid) {
            final m = triad.members[uid];
            final name = m?.name.isNotEmpty == true ? m!.name : 'Без имени';
            return ChoiceChip(
              label: Text(name),
              selected: currentOwner == uid,
              onSelected: (_) => _present(uid),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _sharedNote(ThemeData theme) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: TriadService.instance.sharedSessionStream(triad.id),
      builder: (context, sessionSnap) {
        final session = sessionSnap.data;
        if (session == null || session['ownerUid'] == null) {
          return Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                  'Никто пока не показывает заметку. Нажмите на имя участника '
                  'выше — и она откроется у всех.'),
            ),
          );
        }

        final ownerUid = session['ownerUid'] as String;
        final dateStr = (session['date'] as String?) ?? dateKey(_date);
        final owner = triad.members[ownerUid];
        final ownerName =
            owner?.name.isNotEmpty == true ? owner!.name : 'Без имени';
        final day = DateTime.tryParse(dateStr) ?? _date;

        return StreamBuilder<Note?>(
          stream: NotesRepository.instance.memberNoteStream(ownerUid, day),
          builder: (context, noteSnap) {
            final note = noteSnap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Показывается: $ownerName',
                          style: theme.textTheme.titleMedium),
                    ),
                  ],
                ),
                Text(humanDate(day),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 12),
                if (note == null || note.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('$ownerName не заполнял заметку за этот день.'),
                    ),
                  )
                else
                  ...List.generate(kNoteFieldCount, (i) {
                    final answer = note.answers[i].trim();
                    if (answer.isEmpty) return const SizedBox.shrink();
                    return Card(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kNoteQuestions[i],
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary)),
                            const SizedBox(height: 4),
                            Text(answer,
                                style: theme.textTheme.bodyLarge
                                    ?.copyWith(height: 1.4)),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }
}
