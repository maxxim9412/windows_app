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
final RegExp _re = RegExp(
  r'^\s*([1-3]?\s*[А-Яа-яЁё.]+)\s+(\d+)\s*[:.]\s*(\d+)(?:\s*[–—-]\s*(\d+))?\.?\s*$',
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
