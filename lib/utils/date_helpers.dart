import 'package:intl/intl.dart';

/// Ключ даты в формате yyyy-MM-dd (используется как id дня в БД).
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// true для понедельника–пятницы (для отрывков QT).
bool isWeekday(DateTime d) => d.weekday >= DateTime.monday && d.weekday <= DateTime.friday;

/// true для понедельника–субботы (план чтения — 6 дней, кроме воскресенья).
bool isReadingDay(DateTime d) => d.weekday != DateTime.sunday;

/// Человекочитаемая дата на русском, напр. «понедельник, 14 июля».
String humanDate(DateTime d) => DateFormat('EEEE, d MMMM', 'ru').format(d);

String humanDateShort(DateTime d) => DateFormat('d MMM yyyy', 'ru').format(d);
