import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/progress_repository.dart';
import '../utils/date_helpers.dart';

/// Календарь с отметками: что сделано, что пропущено. Выбор дня возвращается
/// вызывающему экрану через Navigator.pop.
///
/// Будущие дни выбрать нельзя — тройка идёт по графику вместе, забегать вперёд
/// незачем. Дни без графика (выходные) не выбираются: делать там нечего.
class ProgressCalendarScreen extends StatefulWidget {
  const ProgressCalendarScreen({super.key, required this.selected});

  /// Сейчас открытый день — подсвечиваем его в сетке.
  final DateTime selected;

  @override
  State<ProgressCalendarScreen> createState() => _ProgressCalendarScreenState();
}

class _ProgressCalendarScreenState extends State<ProgressCalendarScreen> {
  static const _doneColor = Color(0xFF2E7D32); // зелёный — сделано
  static const _missedColor = Color(0xFFEF6C00); // оранжевый — пропущено

  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);
  MonthProgress? _progress;
  bool _loading = true;

  final _today = dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await ProgressRepository.instance.forMonth(_month);
    if (!mounted) return;
    setState(() {
      _progress = p;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Мой прогресс')),
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
    final p = _progress?.forDay(day);
    final isToday = day == _today;
    final isSelected = day == dateOnly(widget.selected);
    final isFuture = day.isAfter(_today);
    final scheduled = p?.scheduled ?? false;
    final selectable = scheduled && !isFuture;

    Color dot(bool has, bool done) {
      if (!has) return Colors.transparent;
      if (done) return _doneColor;
      if (isFuture || isToday) return theme.colorScheme.outlineVariant;
      return _missedColor;
    }

    return InkWell(
      onTap: selectable ? () => Navigator.pop(context, day) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
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
                color: isFuture || !scheduled
                    ? theme.colorScheme.outline
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(dot(p?.hasQt ?? false, p?.qtDone ?? false)),
                const SizedBox(width: 3),
                _dot(dot(p?.hasReading ?? false, p?.readingDone ?? false)),
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
    Widget row(Color c, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              _dot(c),
              const SizedBox(width: 10),
              Text(text, style: theme.textTheme.bodySmall),
            ],
          ),
        );
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Обозначения', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            Text('В клетке две точки: слева — QT, справа — чтение.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 10),
            row(_doneColor, 'сделано'),
            row(_missedColor, 'пропущено — можно наверстать'),
            row(theme.colorScheme.outlineVariant, 'ещё не сделано (сегодня)'),
            const SizedBox(height: 6),
            Text(
              'Пустая клетка без точек — на этот день ничего не назначено. '
              'Нажмите на день, чтобы открыть его отрывок и чтение.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
