import 'bible_abbrev.dart';

/// Разобранный адрес отрывка.
class ParsedReference {
  final String bookCode;
  final int chapter;
  final int verseStart;
  final int verseEnd;
  const ParsedReference(
      this.bookCode, this.chapter, this.verseStart, this.verseEnd);
}

/// Результат разбора одной строки.
class ParseLineResult {
  final String raw;
  final ParsedReference? ref;
  final String? error;
  const ParseLineResult(this.raw, {this.ref, this.error});
  bool get ok => ref != null;
}

// Пример распознаваемых строк:
//   Ин 3:16-17    Мф 5:3–10    Пс 22:1-6    1 Кор 13:1-7    Ин 3:16
// Разделитель книги и главы — пробел ИЛИ точка («Ин 3:16», «Лев.16:1-34»).
final RegExp _re = RegExp(
  r'^\s*([1-3]?\s*[А-Яа-яЁё]+\.?)\s*(\d+)\s*[:.]\s*(\d+)(?:\s*[–—-]\s*(\d+))?\.?\s*$',
);

/// Разбирает одну строку с сокращённым адресом.
ParseLineResult parseReferenceLine(String raw) {
  final line = raw.trim();
  if (line.isEmpty) return ParseLineResult(raw, error: 'пустая строка');

  final m = _re.firstMatch(line);
  if (m == null) {
    return ParseLineResult(raw,
        error: 'не распознан формат (нужно, напр., «Ин 3:16-17»)');
  }

  final code = bookCodeFromAbbrev(m.group(1)!);
  if (code == null) {
    return ParseLineResult(raw, error: 'неизвестная книга «${m.group(1)!.trim()}»');
  }

  final chapter = int.parse(m.group(2)!);
  final vs = int.parse(m.group(3)!);
  final ve = m.group(4) != null ? int.parse(m.group(4)!) : vs;
  if (ve < vs) {
    return ParseLineResult(raw, error: 'конечный стих меньше начального');
  }

  return ParseLineResult(raw, ref: ParsedReference(code, chapter, vs, ve));
}

/// Разбирает многострочный текст (одна строка = один отрывок).
List<ParseLineResult> parseReferenceList(String text) {
  return text
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .map(parseReferenceLine)
      .toList();
}

// --- Разбор глав (для плана чтения) -------------------------------------

/// Разобранный диапазон глав (без стихов).
class ParsedChapters {
  final String bookCode;
  final int chapterStart;
  final int chapterEnd;
  const ParsedChapters(this.bookCode, this.chapterStart, this.chapterEnd);
}

class ParseChapterResult {
  final String raw;
  final ParsedChapters? ref;
  final String? error;
  const ParseChapterResult(this.raw, {this.ref, this.error});
  bool get ok => ref != null;
}

// Пример: «Быт 1-3», «Мф 5», «Пс 1–2», «1 Кор 13»
final RegExp _reChapters = RegExp(
  r'^\s*([1-3]?\s*[А-Яа-яЁё]+\.?)\s*(\d+)(?:\s*[–—-]\s*(\d+))?\.?\s*$',
);

ParseChapterResult parseChapterLine(String raw) {
  final line = raw.trim();
  if (line.isEmpty) return ParseChapterResult(raw, error: 'пустая строка');

  final m = _reChapters.firstMatch(line);
  if (m == null) {
    return ParseChapterResult(raw,
        error: 'не распознан формат (нужно, напр., «Быт 1-3» или «Мф 5»)');
  }

  final code = bookCodeFromAbbrev(m.group(1)!);
  if (code == null) {
    return ParseChapterResult(raw,
        error: 'неизвестная книга «${m.group(1)!.trim()}»');
  }

  final cs = int.parse(m.group(2)!);
  final ce = m.group(3) != null ? int.parse(m.group(3)!) : cs;
  if (ce < cs) {
    return ParseChapterResult(raw, error: 'конечная глава меньше начальной');
  }

  return ParseChapterResult(raw, ref: ParsedChapters(code, cs, ce));
}

List<ParseChapterResult> parseChapterList(String text) {
  return text
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .map(parseChapterLine)
      .toList();
}
