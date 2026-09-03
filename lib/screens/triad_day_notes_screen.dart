import 'package:flutter/material.dart';

import '../data/notes_repository.dart';
import '../models/note.dart';
import '../models/triad.dart';
import '../services/auth_service.dart';
import '../utils/date_helpers.dart';
import '../utils/note_questions.dart';
import '../widgets/member_avatar.dart';
import '../utils/app_dimens.dart';

/// Заметки участников тройки за один конкретный день (из календаря тройки).
/// По сути то же самое, что список участников с отметками «сделал заметку
/// сегодня» на самом экране тройки, только день — любой из прошлого, а не
/// всегда сегодня.
class TriadDayNotesScreen extends StatefulWidget {
  const TriadDayNotesScreen({super.key, required this.triad, required this.day});

  final Triad triad;
  final DateTime day;

  @override
  State<TriadDayNotesScreen> createState() => _TriadDayNotesScreenState();
}

class _TriadDayNotesScreenState extends State<TriadDayNotesScreen> {
  final Map<String, Stream<Note?>> _streams = {};

  Stream<Note?> _streamFor(String uid) => _streams.putIfAbsent(
      uid, () => NotesRepository.instance.memberNoteStream(uid, widget.day));

  void _view(TriadMember? m, Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(m?.name ?? '', style: Theme.of(context).textTheme.titleLarge),
            Text(humanDate(widget.day),
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 24),
            for (var i = 0; i < kNoteFieldCount; i++)
              if (note.answers[i].trim().isNotEmpty) ...[
                Text(kNoteQuestions[i],
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(note.answers[i]),
                const SizedBox(height: 16),
              ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final triad = widget.triad;
    final myUid = AuthService.instance.uid;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Заметки за день'),
            Text(humanDate(widget.day),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: triad.memberUids.map((uid) {
          final m = triad.members[uid];
          final isMe = uid == myUid;
          return StreamBuilder<Note?>(
            stream: _streamFor(uid),
            builder: (context, snap) {
              final note = snap.data;
              final done = note != null && note.isDone;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: MemberAvatar(
                    name: m?.name ?? '?',
                    photoBase64: m?.photo,
                  ),
                  title: Text(
                      '${m?.name.isNotEmpty == true ? m!.name : 'Без имени'}'
                      '${isMe ? ' (вы)' : ''}'),
                  subtitle:
                      Text(done ? 'Есть заметка — нажмите' : 'Нет заметки'),
                  trailing: Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: done
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  onTap: done ? () => _view(m, note) : null,
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
