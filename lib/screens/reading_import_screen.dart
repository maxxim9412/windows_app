import 'package:flutter/material.dart';

import '../data/reading_repository.dart';
import '../models/reading.dart';
import '../utils/bible_books.dart';
import '../utils/date_helpers.dart';
import '../utils/reference_parser.dart';

/// Одна строка = один день чтения; в строке может быть несколько глав через «;».
class _DayImport {
  final String rawLine;
  final List<ParseChapterResult> portions;
  DateTime? date;
  _DayImport(this.rawLine, this.portions, this.date);
  bool get hasValid => portions.any((p) => p.ok);
}

/// Массовый импорт плана чтения: список глав → раскладка по дням (6/нед, кроме вс).
class ReadingImportScreen extends StatefulWidget {
  const ReadingImportScreen({super.key});

  @override
  State<ReadingImportScreen> createState() => _ReadingImportScreenState();
}

class _ReadingImportScreenState extends State<ReadingImportScreen> {
  final _textCtrl = TextEditingController();
  late DateTime _startDate = _nextReadingDayOnOrAfter(dateOnly(DateTime.now()));

  List<_DayImport> _days = const [];
  bool _previewed = false;

  static DateTime _nextReadingDayOnOrAfter(DateTime d) {
    var day = d;
    while (!isReadingDay(day)) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _preview() {
    final lines =
        _textCtrl.text.split('\n').where((l) => l.trim().isNotEmpty);
    final days = <_DayImport>[];
    var day = _nextReadingDayOnOrAfter(_startDate);
    for (final line in lines) {
      final portions = line
          .split(';')
          .where((p) => p.trim().isNotEmpty)
          .map(parseChapterLine)
          .toList();
      final di = _DayImport(line, portions, null);
      if (di.hasValid) {
        di.date = day;
        day = _nextReadingDayOnOrAfter(day.add(const Duration(days: 1)));
      }
      days.add(di);
    }
    setState(() {
      _days = days;
      _previewed = true;
    });
  }

  int get _validDayCount => _days.where((d) => d.hasValid).length;

  Future<void> _import() async {
    var count = 0;
    for (final di in _days) {
      if (di.date == null) continue;
      final key = dateKey(di.date!);
      final items = <Reading>[];
      for (final p in di.portions) {
        if (!p.ok) continue;
        items.add(Reading(
          date: key,
          bookCode: p.ref!.bookCode,
          chapterStart: p.ref!.chapterStart,
          chapterEnd: p.ref!.chapterEnd,
        ));
      }
      await ReadingRepository.instance.setDateItems(key, items);
      count++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Импортировано дней чтения: $count')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Импорт плана чтения')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Вставьте главы — по одной строке на день. Несколько глав в один день '
            'разделяйте «;». Раскладка идёт 6 дней в неделю (воскресенье '
            'пропускается), начиная с выбранной даты.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Примеры формата:\nБыт 1-3\nБыт 4-6; Пс 1\nМф 5; Мф 6',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Начать с даты'),
            subtitle: Text(humanDateShort(_startDate)),
            trailing: TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    _startDate = _nextReadingDayOnOrAfter(dateOnly(picked));
                    _previewed = false;
                  });
                }
              },
              child: const Text('Выбрать'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textCtrl,
            maxLines: null,
            minLines: 6,
            decoration: const InputDecoration(
              hintText: 'Быт 1-3\nБыт 4-6; Пс 1\n…',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_previewed) setState(() => _previewed = false);
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _preview,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Предпросмотр'),
          ),
          if (_previewed) ...[
            const SizedBox(height: 16),
            Text('Результат разбора', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._buildPreviewRows(theme),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _validDayCount > 0 ? _import : null,
              child: Text(_validDayCount > 0
                  ? 'Импортировать дней: $_validDayCount (заменит совпадающие дни)'
                  : 'Нет корректных строк'),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildPreviewRows(ThemeData theme) {
    final rows = <Widget>[];
    for (final di in _days) {
      if (di.date != null) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(humanDateShort(di.date!),
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.primary)),
        ));
      }
      for (final p in di.portions) {
        if (p.ok) {
          final ref = p.ref!;
          final ch = ref.chapterStart == ref.chapterEnd
              ? '${ref.chapterStart}'
              : '${ref.chapterStart}–${ref.chapterEnd}';
          rows.add(ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 8),
            leading: Icon(Icons.check_circle,
                color: theme.colorScheme.primary, size: 20),
            title: Text('${bookName(ref.bookCode)} $ch'),
          ));
        } else {
          rows.add(ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 8),
            leading: Icon(Icons.error_outline,
                color: theme.colorScheme.error, size: 20),
            title: Text(p.raw.trim(),
                style: TextStyle(color: theme.colorScheme.error)),
            subtitle: Text(p.error ?? 'ошибка',
                style: TextStyle(color: theme.colorScheme.error)),
          ));
        }
      }
    }
    return rows;
  }
}
