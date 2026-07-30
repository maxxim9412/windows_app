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
import '../widgets/member_avatar.dart';
import '../utils/app_dimens.dart';

/// Раздел троек: человек может состоять в нескольких (вторую и далее открывает
/// админ церкви). Одна тройка показывается развёрнуто как раньше; несколько —
/// сворачивающимся списком, чтобы экран не разрастался.
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
  late final Stream<List<Triad>> _stream = TriadService.instance.myTriadsStream();
  late final Stream<String?> _pendingStream =
      TriadService.instance.pendingTriadIdStream();
  // Лимит читается один раз на показ вкладки: меняется он редко (действием
  // админа), после его повышения достаточно перезайти на вкладку.
  late final Future<int> _limitFuture = TriadService.instance.myTriadLimit();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Triad>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final triads = snap.data ?? const <Triad>[];
        return StreamBuilder<String?>(
          stream: _pendingStream,
          builder: (context, pendSnap) {
            final pendingId = pendSnap.data;
            if (triads.isEmpty && pendingId == null) return const _EntryView();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (triads.length == 1)
                  // Одна тройка — как всегда, без лишнего сворачивания.
                  _MemberView(triad: triads.first)
                else
                  for (var i = 0; i < triads.length; i++) ...[
                    _TriadSection(
                      // Ключ по id: иначе при выходе из тройки состояние
                      // раскрытия «переехало» бы на соседнюю.
                      key: ValueKey(triads[i].id),
                      triad: triads[i],
                      index: i,
                      initiallyExpanded: i == 0,
                    ),
                    const SizedBox(height: 8),
                  ],
                if (pendingId != null) ...[
                  if (triads.isNotEmpty) const SizedBox(height: 16),
                  _PendingView(triadId: pendingId),
                ] else if (triads.isNotEmpty)
                  FutureBuilder<int>(
                    future: _limitFuture,
                    builder: (context, limSnap) {
                      final limit = limSnap.data ?? 1;
                      if (triads.length >= limit) {
                        return const SizedBox.shrink();
                      }
                      return const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: _ExtraTriadCard(),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// --- Общие действия входа в тройку ----------------------------------------

Future<void> _createTriadFlow(BuildContext context) async {
  try {
    await TriadService.instance.createTriad();
  } catch (e) {
    if (context.mounted) _snack(context, e.toString());
  }
}

Future<void> _joinTriadFlow(BuildContext context) async {
  final ctrl = TextEditingController();
  final input = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Вступить в тройку'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Введите код приглашения',
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

// --- Нет ни одной тройки ---------------------------------------------------

class _EntryView extends StatelessWidget {
  const _EntryView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
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
          onPressed: () => _createTriadFlow(context),
          icon: const Icon(Icons.group_add),
          label: const Text('Создать тройку'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _joinTriadFlow(context),
          icon: const Icon(Icons.link),
          label: const Text('Вступить по коду'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ],
    );
  }
}

// --- Секция одной тройки в списке из нескольких ----------------------------

class _TriadSection extends StatelessWidget {
  const _TriadSection({
    super.key,
    required this.triad,
    required this.index,
    required this.initiallyExpanded,
  });

  final Triad triad;
  final int index;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = triad.memberUids
        .map((uid) => triad.members[uid]?.name)
        .map((n) => (n == null || n.isEmpty) ? 'Без имени' : n)
        .join(' · ');
    // Заявки/согласия внутри свёрнутой секции легко пропустить — выносим
    // маркер наружу.
    final needsAttention =
        triad.joinRequests.isNotEmpty || triad.removalRequests.isNotEmpty;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.groups_outlined, color: theme.colorScheme.primary),
        title: Row(
          children: [
            Text('Тройка ${index + 1}',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (needsAttention) ...[
              const SizedBox(width: 8),
              Icon(Icons.mark_chat_unread_outlined,
                  size: 16, color: theme.colorScheme.error),
            ],
          ],
        ),
        subtitle: Text(names,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        children: [_MemberView(triad: triad)],
      ),
    );
  }
}

// --- Карточка «можно ещё одну тройку» --------------------------------------

class _ExtraTriadCard extends StatelessWidget {
  const _ExtraTriadCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Вам открыта ещё одна тройка',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Админ церкви разрешил вам участвовать ещё в одной тройке — '
              'создайте её или вступите по коду.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _createTriadFlow(context),
                    icon: const Icon(Icons.group_add),
                    label: const Text('Создать'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _joinTriadFlow(context),
                    icon: const Icon(Icons.link),
                    label: const Text('По коду'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

  // Видели ли мы свою заявку хоть раз в этой сессии. Без этой защёлки нельзя
  // отличить «заявку отклонили» от «первый снимок из кэша ещё без заявки»:
  // Firestore сначала отдаёт кэш (там заявки может не быть), и раньше это
  // ошибочно стирало только что созданную заявку.
  bool _sawRequest = false;

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
        if (stillPending) _sawRequest = true;

        // Заявка обработана: приняли (стали участником) или отклонили (заявка
        // была и пропала). Снимаем только локальную метку ожидания — саму
        // заявку отсюда не трогаем, её уже удалил тот, кто обработал.
        final resolved = becameMember || (_sawRequest && !stillPending);
        if (resolved) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            TriadService.instance.dismissPending();
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
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

        // Участники и отметки «сделал заметку сегодня» — одним списком:
        // имя, контакты и отметка в одной карточке, нажатие открывает заметку.
        Text('Участники (${triad.memberCount}/3)',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _MembersList(
          triad: triad,
          onRemove: (m) => _confirmRemoval(context, m),
        ),

        // Запросы на удаление
        ...triad.removalRequests.map((r) => _removalCard(context, r)),

        // Заявки на вступление (для существующих участников)
        ...triad.joinRequests.map((r) => _joinCard(context, r)),

        // Приглашение (если меньше 3)
        if (!triad.isFull) ...[
          const SizedBox(height: 16),
          _inviteCard(context),
        ],

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
    final code = triad.inviteCode;

    void copy() {
      Clipboard.setData(ClipboardData(text: code));
      _snack(context, 'Код скопирован');
    }

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Пригласить в тройку',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Продиктуйте код или отправьте его — вступают по коду в '
                'разделе «Тройка».',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
            const SizedBox(height: 12),
            // Код крупным текстом. Копирование — на кнопке ниже.
            Text(code,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(letterSpacing: 3)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Share.share(
                      'Присоединяйся к моей тройке в приложении '
                      '«Размышления над Библией».\n'
                      'Код для вступления: $code',
                      subject: 'Приглашение в тройку',
                    ),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Поделиться'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: copy,
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
        padding: const EdgeInsets.all(AppSpacing.md),
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
        padding: const EdgeInsets.all(AppSpacing.md),
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

// --- Участники: контакты + отметка «сделал заметку сегодня» ---------------

class _MembersList extends StatefulWidget {
  final Triad triad;
  final void Function(TriadMember m) onRemove;
  const _MembersList({required this.triad, required this.onRemove});

  @override
  State<_MembersList> createState() => _MembersListState();
}

class _MembersListState extends State<_MembersList> {
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
          padding: const EdgeInsets.all(AppSpacing.lg),
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
    final myUid = AuthService.instance.uid;
    return Column(
      children: triad.memberUids.map((uid) {
        final m = triad.members[uid];
        final isMe = uid == myUid;
        final canRemove = triad.memberCount == 3 &&
            !isMe &&
            !triad.removalRequests.any((r) => r.targetUid == uid);
        return StreamBuilder<Note?>(
          stream: _streamFor(uid),
          builder: (context, snap) {
            final note = snap.data;
            final done = note != null && note.isDone;
            return Card(
              child: ListTile(
                leading: MemberAvatar(
                  name: m?.name ?? '?',
                  photoBase64: m?.photo,
                ),
                title: Text(
                    '${m?.name.isNotEmpty == true ? m!.name : 'Без имени'}'
                    '${isMe ? ' (вы)' : ''}'),
                // Телефон — резервная связь; последняя строка — статус заметки.
                subtitle: Text(
                  [
                    if (m?.email.isNotEmpty ?? false) m!.email,
                    if (m?.phone.isNotEmpty ?? false) m!.phone,
                    done ? 'Сделал заметку — нажмите' : 'Пока нет заметки',
                  ].join('\n'),
                ),
                isThreeLine:
                    (m?.email.isNotEmpty ?? false) || (m?.phone.isNotEmpty ?? false),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canRemove)
                      IconButton(
                        tooltip: 'Предложить удалить',
                        icon: const Icon(Icons.person_remove_outlined),
                        onPressed: () => widget.onRemove(m!),
                      ),
                    Icon(
                      done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: done
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ],
                ),
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
