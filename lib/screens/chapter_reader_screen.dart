import 'package:flutter/material.dart';

import '../data/bible_repository.dart';
import '../data/progress_repository.dart';
import '../data/reading_repository.dart';
import '../models/reading_chapter.dart';

/// Текст одной главы плана. Отдельным экраном — чтобы читать без лишнего, а
/// кнопка отметки лежит под текстом: дочитал — она уже там.
class ChapterReaderScreen extends StatefulWidget {
  const ChapterReaderScreen({
    super.key,
    required this.chapters,
    required this.index,
    required this.day,
  });

  /// Все главы дня — нужны, чтобы перейти к следующей и понять, закрыт ли день.
  final List<ReadingChapter> chapters;
  final int index;
  final DateTime day;

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  List<({int verse, String text})> _verses = const [];
  Set<String> _done = const {};
  bool _loading = true;

  ReadingChapter get _current => widget.chapters[widget.index];
  bool get _hasNext => widget.index + 1 < widget.chapters.length;
  bool get _isDone => _done.contains(_current.key);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = _current.reading;
    var verses =
        await BibleRepository.instance.chapterVerses(r.bookCode, _current.chapter);
    if (r.hasVerses) {
      verses = verses
          .where((v) => v.verse >= r.verseStart! && v.verse <= r.verseEnd!)
          .toList();
    }
    final done = await ReadingRepository.instance.doneChapters(widget.day);
    if (!mounted) return;
    setState(() {
      _verses = verses;
      _done = done;
      _loading = false;
    });
  }

  Future<void> _setDone(bool value) async {
    final next = Set<String>.from(_done);
    value ? next.add(_current.key) : next.remove(_current.key);
    setState(() => _done = next);
    await ReadingRepository.instance.setChapterDone(
      widget.day,
      _current.key,
      value,
      dayComplete: widget.chapters.every((c) => next.contains(c.key)),
    );
    ProgressRepository.instance.invalidate();
  }

  void _goNext() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          chapters: widget.chapters,
          index: widget.index + 1,
          day: widget.day,
        ),
      ),
    );
  }

  Future<void> _markAndContinue() async {
    await _setDone(true);
    if (!mounted) return;
    // Дочитал последнюю — возвращаемся к списку, он покажет день закрытым.
    _hasNext ? _goNext() : Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_current.reference),
            if (widget.chapters.length > 1)
              Text(
                'Глава ${widget.index + 1} из ${widget.chapters.length}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              // Стихи строятся по мере прокрутки: в главе их бывает под сотню.
              itemCount: _verses.length + 1,
              itemBuilder: (context, i) {
                if (i == _verses.length) return _footer(theme);
                final v = _verses[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      children: [
                        TextSpan(
                          text: '${v.verse} ',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: v.text),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _footer(ThemeData theme) {
    if (_verses.isEmpty) {
      return Text(
        'Текста этой главы нет в подключённой базе перевода.',
        style:
            theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Column(
        children: [
          if (_isDone) ...[
            OutlinedButton.icon(
              onPressed: () => _setDone(false),
              icon: const Icon(Icons.check_circle),
              label: const Text('Прочитано — снять отметку'),
              style:
                  OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            if (_hasNext) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _goNext,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Следующая глава'),
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ] else
            FilledButton.icon(
              onPressed: _markAndContinue,
              icon: const Icon(Icons.check),
              label: Text(_hasNext ? 'Прочитано, дальше' : 'ПРОЧИТАНО'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
        ],
      ),
    );
  }
}
