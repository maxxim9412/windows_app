import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/church_repository.dart';
import '../services/auth_service.dart';
import '../utils/bible_books.dart';
import '../utils/date_helpers.dart';
import '../utils/reference_parser.dart';
import '../utils/app_dimens.dart';

/// Удобное заполнение графика церкви на месяц (только админ): вставляешь список
/// QT и список чтения — раскладывается с 1 числа (QT по будням Пн–Пт, чтение
/// 6 дней/нед кроме вс) и ПОЛНОСТЬЮ заменяет график месяца у этой церкви.
///
/// Церковь задаётся явно и всегда видна в шапке. Раньше экран молча писал в
/// церковь самого редактора: супер-админ, правивший «график новой церкви»,
/// на деле переписывал график своей — и об этом ничто не предупреждало.
class MonthlyScheduleScreen extends StatefulWidget {
  const MonthlyScheduleScreen({super.key, this.churchId, this.churchName});

  /// Чей график правим. null — своя церковь (админ церкви из QT/Чтения).
  final String? churchId;
  final String? churchName;

  @override
  State<MonthlyScheduleScreen> createState() => _MonthlyScheduleScreenState();
}

class _MonthlyScheduleScreenState extends State<MonthlyScheduleScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final _qtCtrl = TextEditingController();
  final _readCtrl = TextEditingController();

  String? _churchId;
  String _churchName = '…';
  bool _resolving = true;

  bool _previewed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resolveChurch();
  }

  /// Определяем церковь один раз и запоминаем: дальше пишем только в неё.
  Future<void> _resolveChurch() async {
    var id = widget.churchId;
    var name = widget.churchName;
    if (id == null) {
      id = await AuthService.instance.currentChurchId();
      if (id != null && name == null) {
        name = (await ChurchRepository.instance.byId(id))?.name;
      }
    }
    if (!mounted) return;
    setState(() {
      _churchId = id;
      _churchName = name ?? (id == null ? 'не выбрана' : '—');
      _resolving = false;
    });
  }

  @override
  void dispose() {
    _qtCtrl.dispose();
    _readCtrl.dispose();
    super.dispose();
  }

  // --- Даты месяца --------------------------------------------------------

  List<DateTime> _datesWhere(bool Function(DateTime) test) {
    final last = DateTime(_month.year, _month.month + 1, 0).day;
    return [
      for (var d = 1; d <= last; d++)
        if (test(DateTime(_month.year, _month.month, d)))
          DateTime(_month.year, _month.month, d)
    ];
  }

  List<DateTime> get _weekdayDates => _datesWhere(isWeekday);
  List<DateTime> get _readingDates => _datesWhere(isReadingDay);

  // --- Разбор -------------------------------------------------------------

  List<ParseLineResult> get _qt => parseReferenceList(_qtCtrl.text);

  /// Каждая непустая строка = день чтения; внутри строки главы через «;».
  List<List<ParseChapterResult>> get _reading => _readCtrl.text
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .map((line) => line
          .split(';')
          .where((p) => p.trim().isNotEmpty)
          .map(parseChapterLine)
          .toList())
      .toList();

  List<String> get _errors {
    final errs = <String>[];
    final qt = _qt;
    for (var i = 0; i < qt.length; i++) {
      if (!qt[i].ok) errs.add('QT строка ${i + 1}: «${qt[i].raw.trim()}» — ${qt[i].error}');
    }
    final rd = _reading;
    for (var i = 0; i < rd.length; i++) {
      for (final p in rd[i]) {
        if (!p.ok) {
          errs.add('Чтение строка ${i + 1}: «${p.raw.trim()}» — ${p.error}');
        }
      }
    }
    return errs;
  }

  void _month0(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _previewed = false;
    });
  }

  // --- Применение ---------------------------------------------------------

  Future<void> _apply() async {
    final churchId = _churchId;
    if (churchId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Не выбрана церковь — график привязан к церкви.')));
      }
      return;
    }
    setState(() => _saving = true);
    final db = FirebaseFirestore.instance;
    final church = db.collection('churches').doc(churchId);
    final passages = church.collection('passages');
    final readings = church.collection('readings');
    final batch = db.batch();

    // 1) Полностью очищаем месяц.
    final last = DateTime(_month.year, _month.month + 1, 0).day;
    for (var d = 1; d <= last; d++) {
      final key = dateKey(DateTime(_month.year, _month.month, d));
      batch.delete(passages.doc(key));
      batch.delete(readings.doc(key));
    }

    // 2) QT по будням.
    final wd = _weekdayDates;
    final qt = _qt;
    for (var i = 0; i < qt.length && i < wd.length; i++) {
      final r = qt[i].ref!;
      batch.set(passages.doc(dateKey(wd[i])), {
        'book_code': r.bookCode,
        'chapter': r.chapter,
        'verse_start': r.verseStart,
        'verse_end': r.verseEnd,
      });
    }

    // 3) Чтение по 6 дней/нед.
    final rd = _readingDates;
    final lines = _reading;
    for (var i = 0; i < lines.length && i < rd.length; i++) {
      final items = [
        for (final p in lines[i])
          {
            'book_code': p.ref!.bookCode,
            'chapter_start': p.ref!.chapterStart,
            'chapter_end': p.ref!.chapterEnd,
            if (p.ref!.verseStart != null) 'verse_start': p.ref!.verseStart,
            if (p.ref!.verseEnd != null) 'verse_end': p.ref!.verseEnd,
          }
      ];
      batch.set(readings.doc(dateKey(rd[i])), {'items': items});
    }

    try {
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'График на ${_monthName()} обновлён у церкви «$_churchName».')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    }
  }

  String _monthName() =>
      toBeginningOfSentenceCase(DateFormat('LLLL yyyy', 'ru').format(_month))!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errors = _previewed ? _errors : const <String>[];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('График на месяц'),
            Text(
              _resolving ? '…' : 'Церковь: $_churchName',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Месяц
          Row(
            children: [
              IconButton(
                  onPressed: () => _month0(-1),
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Text(_monthName(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge),
              ),
              IconButton(
                  onPressed: () => _month0(1),
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Вставьте списки — они разложатся с 1 числа. QT — по будням (Пн–Пт), '
            'чтение — 6 дней в неделю (кроме воскресенья). Применение полностью '
            'заменяет график этого месяца у церкви «$_churchName» — и больше '
            'ни у какой.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),

          Text('Отрывки QT (по будням)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          TextField(
            controller: _qtCtrl,
            maxLines: null,
            minLines: 5,
            decoration: const InputDecoration(
              hintText: 'Лев.16:1-34\nЛк.18:9-17\nЛев.17:1-9\n…',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_previewed) setState(() => _previewed = false);
            },
          ),
          const SizedBox(height: 16),

          Text('Чтение (6 дней/нед, несколько глав через «;»)',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          TextField(
            controller: _readCtrl,
            maxLines: null,
            minLines: 5,
            decoration: const InputDecoration(
              hintText: 'Пс.53; Деян.25; Лев.16-17\nПс.54; Деян.26; Лев.18-19\n…',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_previewed) setState(() => _previewed = false);
            },
          ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () => setState(() => _previewed = true),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Предпросмотр'),
          ),

          if (_previewed) ...[
            const SizedBox(height: 16),
            if (errors.isNotEmpty) ...[
              Text('Ошибки — исправьте перед применением:',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              ...errors.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $e',
                        style: TextStyle(color: theme.colorScheme.error)),
                  )),
              const SizedBox(height: 16),
            ],
            Text('Раскладка по дням', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _previewTable(theme),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: errors.isEmpty && !_saving ? _apply : null,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Применить к ${_monthName()} (заменит у всех)'),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _previewTable(ThemeData theme) {
    // Карта дата -> QT
    final qtByDate = <String, ParsedReference>{};
    final wd = _weekdayDates;
    final qt = _qt;
    for (var i = 0; i < qt.length && i < wd.length; i++) {
      if (qt[i].ok) qtByDate[dateKey(wd[i])] = qt[i].ref!;
    }
    // Карта дата -> чтение (строка адресов)
    final readByDate = <String, String>{};
    final rd = _readingDates;
    final lines = _reading;
    for (var i = 0; i < lines.length && i < rd.length; i++) {
      final refs = lines[i]
          .where((p) => p.ok)
          .map((p) {
            final r = p.ref!;
            if (r.verseStart != null) {
              final vs = r.verseStart == r.verseEnd
                  ? '${r.verseStart}'
                  : '${r.verseStart}–${r.verseEnd}';
              return '${bookName(r.bookCode)} ${r.chapterStart}:$vs';
            }
            final ch = r.chapterStart == r.chapterEnd
                ? '${r.chapterStart}'
                : '${r.chapterStart}–${r.chapterEnd}';
            return '${bookName(r.bookCode)} $ch';
          })
          .join('; ');
      readByDate[dateKey(rd[i])] = refs;
    }

    final rows = <Widget>[];
    for (final d in rd) {
      final key = dateKey(d);
      final qtRef = qtByDate[key];
      final qtText = qtRef == null
          ? '—'
          : '${bookName(qtRef.bookCode)} ${qtRef.chapter}:'
              '${qtRef.verseStart == qtRef.verseEnd ? qtRef.verseStart : '${qtRef.verseStart}–${qtRef.verseEnd}'}';
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 84,
                child: Text(humanDateShort(d),
                    style: theme.textTheme.bodySmall)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('QT: $qtText', style: theme.textTheme.bodyMedium),
                  Text('Чтение: ${readByDate[key] ?? '—'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}
