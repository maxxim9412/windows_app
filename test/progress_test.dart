import 'package:bible_reflection/data/progress_repository.dart';
import 'package:bible_reflection/utils/date_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Правила подсчёта пропусков — то, ради чего затевался календарь.
void main() {
  final today = dateOnly(DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));

  MonthProgress monthOf(List<DayProgress> days) => MonthProgress(
        month: DateTime(today.year, today.month),
        days: {for (final d in days) dateKey(d.day): d},
      );

  group('DayProgress', () {
    test('день без графика — не пропуск (выходной)', () {
      final d = DayProgress(day: yesterday);
      expect(d.scheduled, isFalse);
      expect(d.complete, isFalse);
      expect(d.incomplete, isFalse, reason: 'нечего делать — нечего пропускать');
    });

    test('закрыты обе дорожки — день сделан', () {
      final d = DayProgress(
          day: yesterday,
          hasQt: true,
          qtDone: true,
          hasReading: true,
          readingDone: true);
      expect(d.complete, isTrue);
      expect(d.incomplete, isFalse);
    });

    test('чтение сделано, а QT нет — день неполный', () {
      final d = DayProgress(
          day: yesterday,
          hasQt: true,
          qtDone: false,
          hasReading: true,
          readingDone: true);
      expect(d.complete, isFalse);
      expect(d.incomplete, isTrue);
    });

    test('суббота: QT не назначен, чтение прочитано — день сделан', () {
      final d = DayProgress(
          day: yesterday, hasReading: true, readingDone: true);
      expect(d.complete, isTrue, reason: 'отсутствие QT не должно мешать');
    });
  });

  group('MonthProgress.hasGaps', () {
    test('всё закрыто — пропусков нет', () {
      final m = monthOf([
        DayProgress(
            day: yesterday, hasQt: true, qtDone: true),
      ]);
      expect(m.hasGaps, isFalse);
    });

    test('вчера не сделано — есть пропуск', () {
      final m = monthOf([
        DayProgress(day: yesterday, hasQt: true, qtDone: false),
      ]);
      expect(m.hasGaps, isTrue);
    });

    test('сегодня ещё не сделано — это НЕ пропуск', () {
      final m = monthOf([
        DayProgress(day: today, hasQt: true, qtDone: false),
      ]);
      expect(m.hasGaps, isFalse,
          reason: 'день ещё идёт — иначе «!» горел бы каждое утро');
    });

    test('вчера пропущено, сегодня сделано — пропуск остаётся', () {
      final m = monthOf([
        DayProgress(day: yesterday, hasQt: true, qtDone: false),
        DayProgress(day: today, hasQt: true, qtDone: true),
      ]);
      expect(m.hasGaps, isTrue);
    });
  });
}
