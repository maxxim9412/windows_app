import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/notes_repository.dart';
import '../models/triad.dart';
import '../utils/date_helpers.dart';
import '../utils/app_dimens.dart';
import 'triad_day_notes_screen.dart';

/// Календарь тройки: у кого из участников есть заметка в каждый день месяца
/// (по точке на участника). Нажатие на день открывает заметки участников
/// за этот день — в отличие от календаря прогресса в QT/Чтении, это не
/// переключатель текущего дня, а отдельный экран для чтения.
class TriadCalendarScreen extends StatefulWidget {
  const TriadCalendarScreen({super.key, required this.triad});

  final Triad triad;

  @override
  State<TriadCalendarScreen> createState() => _TriadCalendarScreenState();
}

class _TriadCalendarScreenState extends State<TriadCalendarScreen> {
  final _today = dateOnly(DateTime.now());
  late DateTime _month = DateTime(_today.year, _today.month);
  bool _loading = true;

  /// uid участника -> даты (yyyy-MM-dd) этого месяца, когда есть заметка.
  Map<String, Set<String>> _byMember = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = <String, Set<String>>{};
    for (final uid in widget.triad.memberUids) {
      result[uid] =
          await NotesRepository.instance.memberNoteDatesForMonth(uid, _month);
    }
    if (!mounted) return;
    setState(() {
      _byMember = result;
      _loading = false;
    });
  }

  bool get _canGoForward =>
      _month.isBefore(DateTime(_today.year, _today.month));

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  String get _monthName =>
      toBeginningOfSentenceCase(DateFormat('LLLL yyyy', 'ru').format(_month))!;

  Color _colorFor(ThemeData theme, int index) {
    switch (index) {
      case 0:
        return theme.colorScheme.primary;
      case 1:
        return theme.colorScheme.tertiary;
      default:
        return theme.colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Календарь тройки')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftMonth(-1),
                ),
                Expanded(
                  child: Text(_monthName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _canGoForward ? () => _shiftMonth(1) : null,
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  _weekdayHeader(theme),
                  const SizedBox(height: 4),
                  _grid(theme),
                  const SizedBox(height: 24),
                  _legend(theme),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _weekdayHeader(ThemeData theme) {
    const names = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    return Row(
      children: names
          .map((n) => Expanded(
                child: Center(
                  child: Text(n,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ),
              ))
          .toList(),
    );
  }

  Widget _grid(ThemeData theme) {
    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1; // пн = 0

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _dayCell(theme, DateTime(_month.year, _month.month, d)),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: cells,
    );
  }

  Widget _dayCell(ThemeData theme, DateTime day) {
    final isToday = day == _today;
    final isFuture = day.isAfter(_today);
    final key = dateKey(day);
    final memberUids = widget.triad.memberUids;
    final selectable = !isFuture;

    return InkWell(
      onTap: selectable
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TriadDayNotesScreen(triad: widget.triad, day: day),
                ),
              )
          : null,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isFuture
                    ? theme.colorScheme.outline
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < memberUids.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  _dot(
                    (_byMember[memberUids[i]]?.contains(key) ?? false)
                        ? _colorFor(theme, i)
                        : theme.colorScheme.outlineVariant,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _legend(ThemeData theme) {
    final triad = widget.triad;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Обозначения', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            for (var i = 0; i < triad.memberUids.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    _dot(_colorFor(theme, i)),
                    const SizedBox(width: 10),
                    Text(
                      (triad.members[triad.memberUids[i]]?.name.isNotEmpty ??
                              false)
                          ? triad.members[triad.memberUids[i]]!.name
                          : 'Без имени',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Точка закрашена — участник написал заметку в этот день. '
              'Нажмите на день, чтобы почитать.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
