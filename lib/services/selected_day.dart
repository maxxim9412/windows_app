import 'package:flutter/foundation.dart';

import '../utils/date_helpers.dart';

/// День, который сейчас открыт в QT и Чтении. Общий на оба экрана: догоняя
/// пропущенный день, человек делает и заметку, и чтение — выбирать дату дважды
/// было бы лишним.
///
/// При запуске приложения всегда сегодня: [instance] живёт столько же, сколько
/// процесс, так что «залипнуть» на прошлой дате между сессиями нельзя.
class SelectedDay extends ValueNotifier<DateTime> {
  SelectedDay._() : super(dateOnly(DateTime.now()));
  static final SelectedDay instance = SelectedDay._();

  static DateTime get today => dateOnly(DateTime.now());

  bool get isToday => value == today;

  void select(DateTime day) => value = dateOnly(day);

  void backToToday() => value = today;
}
