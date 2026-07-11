import 'package:flutter/material.dart';

import '../data/reading_repository.dart';
import '../models/reading.dart';
import '../utils/bible_books.dart';
import '../utils/date_helpers.dart';
import '../utils/reference_parser.dart';

/// Массовый импорт плана чтения: список глав → раскладка по дням (6/нед, кроме вс).
class ReadingImportScreen extends StatefulWidget {
  const ReadingImportScreen({super.key});

  @override
  State<ReadingImportScreen> createState() => _ReadingImportScreenState();
}

class _ReadingImportScreenState extends State<ReadingImportScreen> {
  final _textCtrl = TextEditingController();
  late DateTime _startDate = _nextReadingDayOnOrAfter(dateOnly(DateTime.now()));

  List<ParseChapterResult> _results = const [];
  List<DateTime?> _dates = const [];
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
    final results = parseChapterList(_textCtrl.text);
    final dates = <DateTime?>[];
    var day = _nextReadingDayOnOrAfter(_startDate);
    for (final r in results) {
      if (r.ok) {
        dates.add(day);
        day = _nextReadingDayOnOrAfter(day.add(const Duration(days: 1)));
      } else {
        dates.add(null);
      }
    }
    setState(() {
      _results = results;
      _dates = dates;
      _previewed = true;
    });
  }

  int get _validCount => _results.where((r) => r.ok).length;

  Future<void> _import() async {
    var count = 0;
    for (var i = 0; i < _results.length; i++) {
      final r = _results[i];
      final date = _dates[i];
      if (r.ok && date != null) {
        // Один импортируемый день заменяет прежнее чтение этого дня.
        await ReadingRepository.instance.deleteDate(dateKey(date));
        await ReadingRepository.instance.insert(Reading(
          date: dateKey(date),
          bookCode: r.ref!.bookCode,
          chapterStart: r.ref!.chapterStart,
          chapterEnd: r.ref!.chapterEnd,
        ));
        count++;
      }
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
            'Вставьте главы — по одной строке на день. Раскладка идёт 6 дней в '
            'неделю (воскресенье пропускается), начиная с выбранной даты.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Примеры формата:\nБыт 1-3\nБыт 4-6\nМф 5\nПс 1-2',
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
              hintText: 'Быт 1-3\nБыт 4-6\n…',
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
              onPressed: _validCount > 0 ? _import : null,
              child: Text(_validCount > 0
                  ? 'Импортировать: $_validCount (заменит совпадающие дни)'
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
    for (var i = 0; i < _results.length; i++) {
      final r = _results[i];
      if (r.ok) {
        final ref = r.ref!;
        final ch = ref.chapterStart == ref.chapterEnd
            ? '${ref.chapterStart}'
            : '${ref.chapterStart}–${ref.chapterEnd}';
        rows.add(ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.check_circle,
              color: theme.colorScheme.primary, size: 20),
          title: Text('${bookName(ref.bookCode)} $ch'),
          trailing: Text(humanDateShort(_dates[i]!),
              style: theme.textTheme.bodySmall),
        ));
      } else {
        rows.add(ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.error_outline,
              color: theme.colorScheme.error, size: 20),
          title: Text(r.raw.trim(),
              style: TextStyle(color: theme.colorScheme.error)),
          subtitle: Text(r.error ?? 'ошибка',
              style: TextStyle(color: theme.colorScheme.error)),
        ));
      }
    }
    return rows;
  }
}
