import 'package:flutter/material.dart';

import '../data/passage_repository.dart';
import '../models/passage.dart';
import '../utils/bible_books.dart';
import '../utils/date_helpers.dart';
import '../utils/reference_parser.dart';
import '../utils/app_dimens.dart';

/// Массовый импорт отрывков: вставка списка сокращённых адресов
/// с автоматической раскладкой по будним дням.
class AdminImportScreen extends StatefulWidget {
  const AdminImportScreen({super.key});

  @override
  State<AdminImportScreen> createState() => _AdminImportScreenState();
}

class _AdminImportScreenState extends State<AdminImportScreen> {
  final _textCtrl = TextEditingController();
  late DateTime _startDate = _nextWeekdayOnOrAfter(dateOnly(DateTime.now()));

  List<ParseLineResult> _results = const [];
  List<DateTime?> _dates = const []; // дата для каждой валидной строки
  bool _previewed = false;

  static DateTime _nextWeekdayOnOrAfter(DateTime d) {
    var day = d;
    while (!isWeekday(day)) {
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
    final results = parseReferenceList(_textCtrl.text);
    // Раскладываем валидные по будням, начиная с _startDate.
    final dates = <DateTime?>[];
    var day = _nextWeekdayOnOrAfter(_startDate);
    for (final r in results) {
      if (r.ok) {
        dates.add(day);
        day = _nextWeekdayOnOrAfter(day.add(const Duration(days: 1)));
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
        await PassageRepository.instance.upsert(Passage(
          date: dateKey(date),
          bookCode: r.ref!.bookCode,
          chapter: r.ref!.chapter,
          verseStart: r.ref!.verseStart,
          verseEnd: r.ref!.verseEnd,
        ));
        count++;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Импортировано отрывков: $count')),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Импорт отрывков')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Вставьте адреса — по одному в строке (можно скопировать столбец из '
            'таблицы). Отрывки разложатся по будням, начиная с выбранной даты. '
            'Выходные пропускаются.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              'Примеры формата:\nИн 3:16-17\nМф 5:3-10\nПс 22:1-6\n1 Кор 13:1-7',
              style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [], color: theme.colorScheme.outline),
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
                    _startDate = _nextWeekdayOnOrAfter(dateOnly(picked));
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
              hintText: 'Ин 3:16-17\nМф 5:3-10\n…',
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
            Text('Результат разбора',
                style: theme.textTheme.titleSmall),
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
        final vs = ref.verseStart == ref.verseEnd
            ? '${ref.verseStart}'
            : '${ref.verseStart}–${ref.verseEnd}';
        rows.add(ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.check_circle,
              color: theme.colorScheme.primary, size: 20),
          title: Text('${bookName(ref.bookCode)} ${ref.chapter}:$vs'),
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
