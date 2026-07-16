import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'shared_meeting_screen.dart';

import '../data/notes_repository.dart';
import '../models/note.dart';
import '../models/triad.dart';
import '../services/auth_service.dart';
import '../services/triad_service.dart';
import '../utils/date_helpers.dart';
import '../utils/note_questions.dart';

/// Раздел управления тройкой: создание, приглашение, участники, согласия,
/// отметки «кто сделал заметку сегодня».
///
/// Все потоки здесь создаются один раз в State, а НЕ в build. Иначе каждая
/// перерисовка сверху (например, когда админ сменил оформление и перестроился
/// MaterialApp) давала бы StreamBuilder новый поток — тот сбрасывался бы в
/// «жду данных» и показывал спиннер вместо содержимого.
class TriadView extends StatefulWidget {
  const TriadView({super.key});

  @override
  State<TriadView> createState() => _TriadViewState();
}

class _TriadViewState extends State<TriadView> {
  late final Stream<Triad?> _stream = TriadService.instance.myTriadStream();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Triad?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final triad = snap.data;
        if (triad != null) return _MemberView(triad: triad);
        return const _NoTriadView();
      },
    );
  }
}

// --- Нет тройки: ожидание заявки или вход/создание -----------------------

class _NoTriadView extends StatefulWidget {
  const _NoTriadView();

  @override
  State<_NoTriadView> createState() => _NoTriadViewState();
}

class _NoTriadViewState extends State<_NoTriadView> {
  late final Stream<String?> _stream =
      TriadService.instance.pendingTriadIdStream();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _stream,
      builder: (context, snap) {
        final pendingId = snap.data;
        if (pendingId != null) return _PendingView(triadId: pendingId);
        return const _EntryView();
      },
    );
  }
}

class _EntryView extends StatelessWidget {
  const _EntryView();

  Future<void> _create(BuildContext context) async {
    try {
      await TriadService.instance.createTriad();
    } catch (e) {
      if (context.mounted) _snack(context, e.toString());
    }
  }

  Future<void> _join(BuildContext context) async {
    final ctrl = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Вступить в тройку'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Вставьте ссылку или код',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Вступить')),
        ],
      ),
    );
    if (input == null || input.trim().isEmpty) return;
    try {
      final outcome = await TriadService.instance.joinByCode(input);
      if (context.mounted) {
        _snack(
            context,
            outcome == JoinOutcome.joined
                ? 'Вы вступили в тройку!'
                : 'Заявка отправлена. Ждём одобрения участников.');
      }
    } catch (e) {
      if (context.mounted) _snack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тройка',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                SizedBox(height: 6),
                Text(
                  'Объединитесь с двумя людьми, чтобы делиться размышлениями и '
                  'видеть, кто сделал заметку сегодня.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _create(context),
          icon: const Icon(Icons.group_add),
          label: const Text('Создать тройку'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _join(context),
          icon: const Icon(Icons.link),
          label: const Text('Вступить по ссылке'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ],
    );
  }
}

class _PendingView extends StatefulWidget {
  final String triadId;
  const _PendingView({required this.triadId});

  @override
  State<_PendingView> createState() => _PendingViewState();
}

class _PendingViewState extends State<_PendingView> {
  late final Stream<Triad?> _stream =
      TriadService.instance.triadStream(widget.triadId);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = AuthService.instance.uid;
    final triadId = widget.triadId;
    return StreamBuilder<Triad?>(
      stream: _stream,
      builder: (context, snap) {
        final triad = snap.data;
        final stillPending =
            triad?.joinRequests.any((r) => r.uid == uid) ?? false;
        final becameMember = triad?.memberUids.contains(uid) ?? false;

        // Если приняли или заявки больше нет — подчищаем pending.
        if (triad != null && (becameMember || !stillPending)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            TriadService.instance.cancelJoinRequest(triadId);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.hourglass_top, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      stillPending
                          ? 'Заявка отправлена. Ждём одобрения участников тройки.'
                          : 'Заявка обработана.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  TriadService.instance.cancelJoinRequest(triadId),
              child: const Text('Отменить заявку'),
            ),
          ],
        );
      },
    );
  }
}

// --- Я в тройке ----------------------------------------------------------

class _MemberView extends StatelessWidget {
  final Triad triad;
  const _MemberView({required this.triad});

  String? get _uid => AuthService.instance.uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = _uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Совместная встреча: аудиозвонок + синхронный просмотр заметок
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SharedMeetingScreen(triad: triad)),
          ),
          icon: const Icon(Icons.headset_mic),
          label: const Text('Совместная встреча'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 16),

        // Участники
        Text('Участники (${triad.memberCount}/3)',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...triad.memberUids.map((memberUid) {
          final m = triad.members[memberUid];
          final isMe = memberUid == uid;
          final canRemove = triad.memberCount == 3 &&
              !isMe &&
              !triad.removalRequests.any((r) => r.targetUid == memberUid);
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  (m?.name.isNotEmpty ?? false)
                      ? m!.name.characters.first.toUpperCase()
                      : '?',
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              ),
              title: Text(
                  '${m?.name.isNotEmpty == true ? m!.name : 'Без имени'}'
                  '${isMe ? ' (вы)' : ''}'),
              // Телефон — резервная связь: почта в срочном случае бесполезна.
              subtitle: Text([
                if (m?.email.isNotEmpty ?? false) m!.email,
                if (m?.phone.isNotEmpty ?? false) m!.phone,
              ].join('\n')),
              isThreeLine: m?.phone.isNotEmpty ?? false,
              trailing: canRemove
                  ? IconButton(
                      tooltip: 'Предложить удалить',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () => _confirmRemoval(context, m!),
                    )
                  : null,
            ),
          );
        }),

        // Запросы на удаление
        ...triad.removalRequests.map((r) => _removalCard(context, r)),

        // Заявки на вступление (для существующих участников)
        ...triad.joinRequests.map((r) => _joinCard(context, r)),

        // Приглашение (если меньше 3)
        if (!triad.isFull) ...[
          const SizedBox(height: 16),
          _inviteCard(context),
        ],

        // Заметки сегодня
        const SizedBox(height: 16),
        Text('Заметки сегодня', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _TodayNotes(triad: triad),

        // Выход из тройки
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _confirmLeave(context),
          icon: const Icon(Icons.logout),
          label: const Text('Выйти из тройки'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: theme.colorScheme.error),
        ),
      ],
    );
  }

  Widget _inviteCard(BuildContext context) {
    final theme = Theme.of(context);
    final link = '${TriadService.inviteBaseUrl}${triad.inviteCode}';
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Пригласить в тройку',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Код: ${triad.inviteCode}',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(letterSpacing: 3)),
            const SizedBox(height: 8),
            Text(link, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Share.share(
                      'Присоединяйся к моей тройке в приложении '
                      '«Размышления над Библией».\nСсылка: $link\n'
                      'Или код: ${triad.inviteCode}',
                      subject: 'Приглашение в тройку',
                    ),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Поделиться'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    _snack(context, 'Ссылка скопирована');
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Копировать'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _joinCard(BuildContext context, JoinRequest r) {
    final theme = Theme.of(context);
    final uid = _uid;
    final approved = uid != null && r.approvals.contains(uid);
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Заявка на вступление: ${r.name}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(r.email, style: theme.textTheme.bodySmall),
            if (r.phone.isNotEmpty)
              Text(r.phone, style: theme.textTheme.bodySmall),
            Text('Одобрений: ${r.approvals.length}/${triad.memberCount}',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            if (approved)
              const Text('Вы одобрили. Ждём остальных.')
            else
              Row(
                children: [
                  FilledButton(
                    onPressed: () =>
                        TriadService.instance.approveJoin(triad.id, r.uid),
                    child: const Text('Одобрить'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        TriadService.instance.declineJoin(triad.id, r.uid),
                    child: const Text('Отклонить'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _removalCard(BuildContext context, RemovalRequest r) {
    final theme = Theme.of(context);
    final uid = _uid;
    final isTarget = r.targetUid == uid;
    final isRequester = r.by == uid;
    final approved = uid != null && r.approvals.contains(uid);
    final others = triad.memberUids.where((m) => m != r.targetUid).length;
    final byName = triad.members[r.by]?.name ?? 'Участник';

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTarget
                  ? 'Предложено удалить вас из тройки'
                  : 'Предложено удалить: ${r.targetName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (!isTarget && !isRequester)
              Text('Инициатор: $byName', style: theme.textTheme.bodySmall),
            Text('Согласий: ${r.approvals.length}/$others',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            if (isTarget)
              const Text('Решение принимают другие участники.')
            else if (isRequester)
              OutlinedButton(
                onPressed: () =>
                    TriadService.instance.cancelRemoval(triad.id, r.targetUid),
                child: const Text('Отменить запрос'),
              )
            else if (!approved)
              Row(
                children: [
                  FilledButton(
                    onPressed: () => TriadService.instance
                        .approveRemoval(triad.id, r.targetUid),
                    child: const Text('Одобрить удаление'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => TriadService.instance
                        .cancelRemoval(triad.id, r.targetUid),
                    child: const Text('Отклонить'),
                  ),
                ],
              )
            else
              const Text('Вы одобрили удаление.'),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoval(BuildContext context, TriadMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить участника?'),
        content: Text(
            'Предложить удалить «${m.name}» из тройки? Второй участник должен '
            'будет одобрить.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Предложить')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await TriadService.instance.requestRemoval(triad.id, m);
      } catch (e) {
        if (context.mounted) _snack(context, e.toString());
      }
    }
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Выйти из тройки?'),
        content: const Text('Вы перестанете видеть заметки участников.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Выйти')),
        ],
      ),
    );
    if (ok == true) {
      await TriadService.instance.leave(triad.id);
    }
  }
}

// --- Заметки участников за сегодня ---------------------------------------

class _TodayNotes extends StatefulWidget {
  final Triad triad;
  const _TodayNotes({required this.triad});

  @override
  State<_TodayNotes> createState() => _TodayNotesState();
}

class _TodayNotesState extends State<_TodayNotes> {
  final _today = dateOnly(DateTime.now());

  /// Поток на участника — заводим по одному разу и держим, иначе перерисовка
  /// пересоздавала бы подписки и отметки «сделал сегодня» мигали бы спиннером.
  final Map<String, Stream<Note?>> _streams = {};

  Stream<Note?> _streamFor(String uid) => _streams.putIfAbsent(
      uid, () => NotesRepository.instance.memberNoteStream(uid, _today));

  void _view(BuildContext context, TriadMember? m, Note note, DateTime today) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text(m?.name ?? '', style: Theme.of(context).textTheme.titleLarge),
            Text(humanDate(today),
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
    final today = _today;
    final triad = widget.triad;
    return Column(
      children: triad.memberUids.map((uid) {
        final m = triad.members[uid];
        return StreamBuilder<Note?>(
          stream: _streamFor(uid),
          builder: (context, snap) {
            final note = snap.data;
            final done = note != null && note.isDone;
            return Card(
              child: ListTile(
                leading: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                title:
                    Text(m?.name.isNotEmpty == true ? m!.name : 'Без имени'),
                subtitle:
                    Text(done ? 'Сделал заметку' : 'Пока нет заметки'),
                trailing: done ? const Icon(Icons.chevron_right) : null,
                onTap: done ? () => _view(context, m, note, today) : null,
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));
}
