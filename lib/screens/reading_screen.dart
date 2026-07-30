import 'package:flutter/material.dart';

import '../data/progress_repository.dart';
import '../data/reading_repository.dart';
import '../models/reading_chapter.dart';
import '../services/auth_service.dart';
import '../services/selected_day.dart';
import '../utils/date_helpers.dart';
import '../widgets/catch_up_banner.dart';
import '../widgets/progress_calendar_button.dart';
import 'chapter_reader_screen.dart';
import 'monthly_schedule_screen.dart';

/// План чтения на день — списком глав. Текст открывается отдельным экраном:
/// день вроде «Быт 1–3» — это под сотню стихов, и одним полотном они читались
/// тяжело.
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  /// Открытый день — общий с экраном QT (см. [SelectedDay]).
  DateTime _day = SelectedDay.instance.value;

  List<ReadingChapter> _chapters = const [];
  Set<String> _done = const {};
  bool _loading = true;
  bool _canEdit = false;

  bool get _isToday => _day == SelectedDay.today;
  bool get _allDone =>
      _chapters.isNotEmpty && _chapters.every((c) => _done.contains(c.key));

  @override
  void initState() {
    super.initState();
    SelectedDay.instance.addListener(_onDayChanged);
    // Не полагаемся на то, что await Navigator.push в _open() дождётся конца
    // чтения: между главами читалка переходит через pushReplacement, а он
    // завершает future самой первой открытой главы сразу же, не дожидаясь
    // остальных — значит, отметки следующих глав иначе не подхватятся.
    // ProgressRepository оповещает после каждой главы, этого достаточно.
    ProgressRepository.instance.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    SelectedDay.instance.removeListener(_onDayChanged);
    ProgressRepository.instance.removeListener(_load);
    super.dispose();
  }

  void _onDayChanged() {
    if (!mounted) return;
    setState(() => _day = SelectedDay.instance.value);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _canEdit = await AuthService.instance.isChurchAdmin();
    final readings = await ReadingRepository.instance.forDate(_day);
    final done = await ReadingRepository.instance.doneChapters(_day);
    if (!mounted) return;
    setState(() {
      _chapters = ReadingChapter.expandAll(readings);
      _done = done;
      _loading = false;
    });
  }

  Future<void> _toggle(ReadingChapter c) async {
    final value = !_done.contains(c.key);
    final next = Set<String>.from(_done);
    value ? next.add(c.key) : next.remove(c.key);
    setState(() => _done = next);

    await ReadingRepository.instance.setChapterDone(
      _day,
      c.key,
      value,
      dayComplete: _chapters.every((x) => next.contains(x.key)),
    );
    ProgressRepository.instance.invalidate();
  }

  Future<void> _open(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          chapters: _chapters,
          index: index,
          day: _day,
        ),
      ),
    );
    _load(); // отметки могли измениться в читалке
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ежедневное чтение'),
        actions: [
          const ProgressCalendarButton(),
          if (_canEdit)
            IconButton(
              tooltip: 'График на месяц',
              icon: const Icon(Icons.edit_calendar_outlined),
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MonthlyScheduleScreen()));
                _load();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isToday) CatchUpBanner(day: _day),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(humanDate(_day),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: theme.colorScheme.primary)),
                      const SizedBox(height: 12),
                      if (_chapters.isEmpty)
                        _emptyCard(theme)
                      else ...[
                        if (_allDone) _doneRow(theme),
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Column(
                            children: [
                              for (var i = 0; i < _chapters.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                _chapterTile(theme, i),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Нажмите на главу, чтобы читать. Кружок слева — '
                          'отметка, если читали не здесь.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _doneRow(ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('Прочитано',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      );

  Widget _chapterTile(ThemeData theme, int i) {
    final c = _chapters[i];
    final done = _done.contains(c.key);
    return ListTile(
      onTap: () => _open(i),
      leading: IconButton(
        tooltip: done ? 'Снять отметку' : 'Отметить прочитанной',
        icon: Icon(
          done ? Icons.check_circle : Icons.circle_outlined,
          color: done ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        onPressed: () => _toggle(c),
      ),
      title: Text(
        c.reference,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: done ? theme.colorScheme.outline : null,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _emptyCard(ThemeData theme) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('На сегодня чтение не назначено.'),
              const SizedBox(height: 8),
              Text(
                'План чтения — 6 дней в неделю (кроме воскресенья). Добавьте главы '
                'в «Плане чтения» (значок календаря вверху).',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      );
}
