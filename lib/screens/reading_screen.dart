import 'package:flutter/material.dart';

import '../data/bible_repository.dart';
import '../data/progress_repository.dart';
import '../data/reading_repository.dart';
import '../models/reading.dart';
import '../services/auth_service.dart';
import '../services/selected_day.dart';
import '../utils/date_helpers.dart';
import '../widgets/catch_up_banner.dart';
import '../widgets/progress_calendar_button.dart';
import 'monthly_schedule_screen.dart';

typedef _ChapterText = ({int chapter, List<({int verse, String text})> verses});
typedef _ReadingBlock = ({Reading reading, List<_ChapterText> chapters});

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  /// Открытый день — общий с экраном QT (см. [SelectedDay]).
  DateTime _day = SelectedDay.instance.value;

  List<_ReadingBlock> _blocks = const [];
  bool _done = false;
  bool _loading = true;
  bool _canEdit = false;

  bool get _isToday => _day == SelectedDay.today;

  @override
  void initState() {
    super.initState();
    SelectedDay.instance.addListener(_onDayChanged);
    _load();
  }

  @override
  void dispose() {
    SelectedDay.instance.removeListener(_onDayChanged);
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
    final done = await ReadingRepository.instance.isDone(_day);

    final blocks = <_ReadingBlock>[];
    for (final r in readings) {
      final chapters = <_ChapterText>[];
      for (final ch in r.chapters) {
        var verses = await BibleRepository.instance.chapterVerses(r.bookCode, ch);
        if (r.hasVerses) {
          verses = verses
              .where((v) => v.verse >= r.verseStart! && v.verse <= r.verseEnd!)
              .toList();
        }
        chapters.add((chapter: ch, verses: verses));
      }
      blocks.add((reading: r, chapters: chapters));
    }

    if (!mounted) return;
    setState(() {
      _blocks = blocks;
      _done = done;
      _loading = false;
    });
  }

  Future<void> _toggleDone(bool value) async {
    setState(() => _done = value);
    await ReadingRepository.instance.setDone(_day, value);
    ProgressRepository.instance.invalidate(); // обновить значок календаря
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
                      if (_blocks.isEmpty)
                        _emptyCard(theme)
                      else ...[
                        if (_done)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Text('Прочитано',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                        color: theme.colorScheme.primary)),
                              ],
                            ),
                          ),
                        ..._blocks.expand((b) => _buildBlock(theme, b)),
                        const SizedBox(height: 8),
                        _doneButton(theme),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _doneButton(ThemeData theme) {
    if (_done) {
      return OutlinedButton.icon(
        onPressed: () => _toggleDone(false),
        icon: const Icon(Icons.check_circle),
        label: const Text('Прочитано — снять отметку'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: () => _toggleDone(true),
      icon: const Icon(Icons.check),
      label: const Text('ПРОЧИТАНО'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
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

  List<Widget> _buildBlock(ThemeData theme, _ReadingBlock block) {
    final widgets = <Widget>[
      Text(block.reading.reference,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
    ];

    final anyText = block.chapters.any((c) => c.verses.isNotEmpty);
    if (!anyText) {
      widgets.add(Text(
        'Текста этих глав нет в подключённой базе перевода.\n'
        'Подключите полный Синодальный перевод (см. README).',
        style:
            theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
      ));
      widgets.add(const SizedBox(height: 16));
      return widgets;
    }

    for (final ch in block.chapters) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text('Глава ${ch.chapter}',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.primary)),
      ));
      if (ch.verses.isEmpty) {
        widgets.add(Text('— нет в базе —',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)));
      } else {
        for (final v in ch.verses) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                children: [
                  TextSpan(
                    text: '${v.verse} ',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: v.text),
                ],
              ),
            ),
          ));
        }
      }
    }
    widgets.add(const SizedBox(height: 16));
    return widgets;
  }
}
