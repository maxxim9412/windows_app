import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/report_repository.dart';
import '../models/triad.dart';

/// Сводка по церкви: сколько троек, кто в них, кому ещё нужен участник.
///
/// Считается по тройкам, а не по профилям: имена участников хранятся в самом
/// документе тройки, поэтому чужие профили открывать не пришлось — история
/// чтения остаётся личной.
class ChurchReportScreen extends StatefulWidget {
  const ChurchReportScreen({
    super.key,
    required this.churchId,
    required this.churchName,
  });

  final String churchId;
  final String churchName;

  @override
  State<ChurchReportScreen> createState() => _ChurchReportScreenState();
}

class _ChurchReportScreenState extends State<ChurchReportScreen> {
  late Future<ChurchReport> _future =
      ReportRepository.instance.forChurch(widget.churchId);

  void _reload() => setState(
      () => _future = ReportRepository.instance.forChurch(widget.churchId));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Отчёт'),
            Text(widget.churchName,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<ChurchReport>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Не удалось построить отчёт.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('${snap.error}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _numbers(theme, r),
              const SizedBox(height: 24),
              if (r.triads.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('В этой церкви пока нет ни одной тройки.'),
                        const SizedBox(height: 8),
                        Text(
                          'Тройки, созданные до появления привязки к церкви, '
                          'сюда не попадают — у них церковь не записана.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (r.incompleteTriads.isNotEmpty) ...[
                  Text('Ищут участников', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...r.incompleteTriads.map((t) => _triadCard(theme, t)),
                  const SizedBox(height: 16),
                ],
                if (r.fullTriads.isNotEmpty) ...[
                  Text('Полные тройки', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...r.fullTriads.map((t) => _triadCard(theme, t)),
                  const SizedBox(height: 16),
                ],
              ],
              if (r.withoutTriad?.isNotEmpty ?? false)
                _withoutTriadSection(theme, r.withoutTriad!),
              const SizedBox(height: 12),
              Text(
                'Нажмите на человека, чтобы скопировать его телефон '
                '(или почту, если телефон не указан).',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _numbers(ThemeData theme, ChurchReport r) {
    final tiles = <Widget>[
      _tile(theme, 'Троек', '${r.triadCount}'),
      _tile(theme, 'Людей в тройках', '${r.peopleInTriads}'),
      if (r.totalMembers != null) _tile(theme, 'Всего людей', '${r.totalMembers}'),
      if (r.withoutTriad != null)
        _tile(theme, 'Без тройки', '${r.withoutTriad!.length}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 12, runSpacing: 12, children: tiles),
        if (r.totalMembers == null) ...[
          const SizedBox(height: 12),
          Text(
            'Общее число людей в церкви видно только главному администратору: '
            'профили прихожан закрыты, и запрет распространяется и на подсчёт.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ],
    );
  }

  Widget _tile(ThemeData theme, String label, String value) => Container(
        width: 150,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.headlineSmall),
          ],
        ),
      );

  void _copy(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Строка человека: имя, почта, телефон. Нажатие копирует телефон, если он
  /// есть, иначе почту — по телефону связываются быстрее.
  Widget _personRow(ThemeData theme, String name, String email,
      [String phone = '']) {
    final primary = phone.isNotEmpty ? phone : email;
    final label = phone.isNotEmpty ? 'Телефон скопирован' : 'Почта скопирована';
    return InkWell(
      onTap: primary.isEmpty ? null : () => _copy(primary, label),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.bodyMedium),
                  if (email.isNotEmpty)
                    Text(email,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  if (phone.isNotEmpty)
                    Text(phone,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
            ),
            if (primary.isNotEmpty)
              Icon(Icons.copy_outlined,
                  size: 16, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  Widget _triadCard(ThemeData theme, Triad t) {
    final emails = t.memberUids
        .map((uid) => t.members[uid]?.email ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  t.isFull ? Icons.groups : Icons.group_add_outlined,
                  size: 18,
                  color: t.isFull
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.isFull
                        ? 'Тройка собрана'
                        : 'Нужно ещё ${3 - t.memberCount}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                if (emails.length > 1)
                  TextButton.icon(
                    onPressed: () =>
                        _copy(emails.join(', '), 'Почты тройки скопированы'),
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Все почты'),
                  ),
              ],
            ),
            const Divider(height: 12),
            for (final uid in t.memberUids)
              _personRow(
                theme,
                (t.members[uid]?.name.isNotEmpty ?? false)
                    ? t.members[uid]!.name
                    : 'Без имени',
                t.members[uid]?.email ?? '',
                t.members[uid]?.phone ?? '',
              ),
            if (t.joinRequests.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Заявок на вступление: ${t.joinRequests.length}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ],
          ],
        ),
      ),
    );
  }

  /// Кто ещё не в тройке — самое полезное для «позвать». Видно только тому, кто
  /// может читать профили, то есть супер-админу.
  Widget _withoutTriadSection(ThemeData theme, List<ChurchPerson> people) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text('Пока без тройки',
                    style: theme.textTheme.titleMedium)),
            if (people.any((p) => p.email.isNotEmpty))
              TextButton.icon(
                onPressed: () => _copy(
                    people
                        .where((p) => p.email.isNotEmpty)
                        .map((p) => p.email)
                        .join(', '),
                    'Почты скопированы'),
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Все почты'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                for (final p in people)
                  _personRow(theme, p.displayName, p.email, p.phone),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
