import 'package:flutter/material.dart';

import '../data/progress_repository.dart';
import '../screens/progress_calendar_screen.dart';
import '../services/selected_day.dart';
import '../utils/status_colors.dart';

/// Кнопка календаря со значком состояния: галочка, если с 1-го числа всё
/// закрыто, и «!», если что-то пропущено. Так пропуск видно, не открывая
/// календарь.
class ProgressCalendarButton extends StatefulWidget {
  const ProgressCalendarButton({super.key});

  @override
  State<ProgressCalendarButton> createState() => _ProgressCalendarButtonState();
}

class _ProgressCalendarButtonState extends State<ProgressCalendarButton> {

  bool? _hasGaps; // null — ещё не посчитали

  @override
  void initState() {
    super.initState();
    ProgressRepository.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    ProgressRepository.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      // Считаем всегда по текущему месяцу, даже если открыт прошлый день.
      final p = await ProgressRepository.instance.forMonth(SelectedDay.today);
      if (!mounted) return;
      setState(() => _hasGaps = p.hasGaps);
    } catch (_) {
      if (mounted) setState(() => _hasGaps = null); // значок просто не покажем
    }
  }

  Future<void> _open() async {
    final day = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProgressCalendarScreen(selected: SelectedDay.instance.value),
      ),
    );
    if (day != null) SelectedDay.instance.select(day);
  }

  @override
  Widget build(BuildContext context) {
    final gaps = _hasGaps;
    final brightness = Theme.of(context).brightness;
    return IconButton(
      tooltip: gaps == true ? 'Есть пропущенные дни' : 'Мой прогресс',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: gaps != null,
        backgroundColor:
            gaps == true ? missedColor(brightness) : doneColor(brightness),
        label: gaps == true
            ? const Text('!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))
            : const Icon(Icons.check, size: 10, color: Colors.white),
        child: const Icon(Icons.calendar_month_outlined),
      ),
    );
  }
}
