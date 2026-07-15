import 'package:flutter/foundation.dart';

import '../utils/date_helpers.dart';
import 'notes_repository.dart';
import 'passage_repository.dart';
import 'reading_repository.dart';

/// Что назначено и что сделано в конкретный день.
class DayProgress {
  final DateTime day;
  final bool hasQt; // назначен отрывок QT
  final bool qtDone; // заметка за день заполнена
  final bool hasReading; // назначено чтение
  final bool readingDone; // нажато «ПРОЧИТАНО»

  const DayProgress({
    required this.day,
    this.hasQt = false,
    this.qtDone = false,
    this.hasReading = false,
    this.readingDone = false,
  });

  /// В этот день вообще есть что делать (в выходные графика нет).
  bool get scheduled => hasQt || hasReading;

  /// Всё назначенное на день закрыто.
  bool get complete =>
      scheduled && (!hasQt || qtDone) && (!hasReading || readingDone);

  /// Назначено, но что-то не сделано. Про «сегодня» так говорить рано —
  /// день ещё не кончился, это решает вызывающий код (см. [MonthProgress.hasGaps]).
  bool get incomplete => scheduled && !complete;
}

/// Прогресс за месяц + сводка для значка на кнопке календаря.
class MonthProgress {
  final DateTime month; // первое число месяца
  final Map<String, DayProgress> days; // ключ — dateKey

  const MonthProgress({required this.month, required this.days});

  DayProgress? forDay(DateTime day) => days[dateKey(day)];

  /// Есть ли пропуски с 1-го числа по вчера включительно.
  ///
  /// Сегодня намеренно не учитываем: день ещё идёт, и иначе значок «!» горел бы
  /// каждое утро до того, как человек сделал QT, — то есть был бы шумом.
  bool get hasGaps {
    final today = dateOnly(DateTime.now());
    return days.values.any((d) => d.incomplete && d.day.isBefore(today));
  }
}

/// Сводный прогресс по дням: собирает график церкви (отрывки + чтение) с
/// личными отметками (заметки + «прочитано»).
///
/// Пропуск виден только так: экран «Мои заметки» перечисляет существующие
/// заметки, а пропущенный день — это как раз день БЕЗ заметки, поэтому считать
/// нужно от графика, а не от заметок.
class ProgressRepository extends ChangeNotifier {
  ProgressRepository._();
  static final ProgressRepository instance = ProgressRepository._();

  MonthProgress? _cache;

  /// Сбросить кэш и оповестить значок на кнопке календаря — вызывать после
  /// сохранения заметки или отметки о чтении.
  void invalidate() {
    _cache = null;
    notifyListeners();
  }

  Future<MonthProgress> forMonth(DateTime month) async {
    final first = DateTime(month.year, month.month);
    final cached = _cache;
    if (cached != null && cached.month == first) return cached;

    // Коллекции маленькие (документ на день), поэтому берём целиком и фильтруем
    // на клиенте — так не нужен запрос по documentId, ненадёжный в вебе.
    final passages = await PassageRepository.instance.all();
    final readings = await ReadingRepository.instance.all();
    final notes = await NotesRepository.instance.all();
    final doneDates = await ReadingRepository.instance.doneDates();

    final noteDates = notes
        .where((n) => !n.isEmpty)
        .map((n) => n.date)
        .toSet();
    final passageDates = passages.map((p) => p.date).toSet();
    final readingDates = readings.map((r) => r.date).toSet();

    final last = DateTime(first.year, first.month + 1, 0).day;
    final days = <String, DayProgress>{};
    for (var d = 1; d <= last; d++) {
      final day = DateTime(first.year, first.month, d);
      final key = dateKey(day);
      days[key] = DayProgress(
        day: day,
        hasQt: passageDates.contains(key),
        qtDone: noteDates.contains(key),
        hasReading: readingDates.contains(key),
        readingDone: doneDates.contains(key),
      );
    }
    return _cache = MonthProgress(month: first, days: days);
  }
}
