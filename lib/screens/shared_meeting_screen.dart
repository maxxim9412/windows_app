import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/notes_repository.dart';
import '../models/note.dart';
import '../models/triad.dart';
import '../services/triad_service.dart';
import '../utils/date_helpers.dart';
import '../utils/note_questions.dart';

/// Совместная встреча тройки: аудиозвонок (Jitsi) + синхронно показываемая
/// заметка. У всех троих открыта одна и та же заметка; любой может показать
/// свою или переключить на чужую.
class SharedMeetingScreen extends StatefulWidget {
  final Triad triad;
  const SharedMeetingScreen({super.key, required this.triad});

  @override
  State<SharedMeetingScreen> createState() => _SharedMeetingScreenState();
}

class _SharedMeetingScreenState extends State<SharedMeetingScreen> {
  DateTime _date = dateOnly(DateTime.now());

  Triad get triad => widget.triad;

  Future<void> _startAudioCall() async {
    final uri = Uri.parse(
        'https://meet.jit.si/BibleReflectionTriad${triad.id}#config.startAudioOnly=true');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть аудиозвонок')),
      );
    }
  }

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
          FilledButton.icon(
            onPressed: _startAudioCall,
            icon: const Icon(Icons.call),
            label: const Text('Аудиозвонок'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 6),
          Text(
            'Звонок откроется в Jitsi. Вернитесь в приложение — разговор '
            'продолжится в фоне, и здесь можно вместе смотреть заметки.',
            style:
                theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const Divider(height: 32),

          // Выбор дня
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

          // Синхронно показываемая заметка
          _sharedNote(theme),
          const SizedBox(height: 32),
        ],
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
