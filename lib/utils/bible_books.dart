/// Список книг Библии (Синодальный канон) с короткими кодами.
/// Код используется как ключ в базе перевода (assets/bible/*.json).
class BibleBook {
  final String code;
  final String name;
  const BibleBook(this.code, this.name);
}

/// 66 книг канонического состава. Неканонические можно добавить при желании.
const List<BibleBook> kBibleBooks = [
  // Ветхий Завет
  BibleBook('gen', 'Бытие'),
  BibleBook('exo', 'Исход'),
  BibleBook('lev', 'Левит'),
  BibleBook('num', 'Числа'),
  BibleBook('deu', 'Второзаконие'),
  BibleBook('jos', 'Иисус Навин'),
  BibleBook('jdg', 'Судьи'),
  BibleBook('rut', 'Руфь'),
  BibleBook('1sa', '1-я Царств'),
  BibleBook('2sa', '2-я Царств'),
  BibleBook('1ki', '3-я Царств'),
  BibleBook('2ki', '4-я Царств'),
  BibleBook('1ch', '1-я Паралипоменон'),
  BibleBook('2ch', '2-я Паралипоменон'),
  BibleBook('ezr', 'Ездра'),
  BibleBook('neh', 'Неемия'),
  BibleBook('est', 'Есфирь'),
  BibleBook('job', 'Иов'),
  BibleBook('ps', 'Псалтирь'),
  BibleBook('pro', 'Притчи'),
  BibleBook('ecc', 'Екклесиаст'),
  BibleBook('sng', 'Песни Песней'),
  BibleBook('isa', 'Исаия'),
  BibleBook('jer', 'Иеремия'),
  BibleBook('lam', 'Плач Иеремии'),
  BibleBook('ezk', 'Иезекииль'),
  BibleBook('dan', 'Даниил'),
  BibleBook('hos', 'Осия'),
  BibleBook('jol', 'Иоиль'),
  BibleBook('amo', 'Амос'),
  BibleBook('oba', 'Авдий'),
  BibleBook('jon', 'Иона'),
  BibleBook('mic', 'Михей'),
  BibleBook('nam', 'Наум'),
  BibleBook('hab', 'Аввакум'),
  BibleBook('zep', 'Софония'),
  BibleBook('hag', 'Аггей'),
  BibleBook('zec', 'Захария'),
  BibleBook('mal', 'Малахия'),
  // Новый Завет
  BibleBook('mf', 'От Матфея'),
  BibleBook('mk', 'От Марка'),
  BibleBook('lk', 'От Луки'),
  BibleBook('jn', 'От Иоанна'),
  BibleBook('act', 'Деяния'),
  BibleBook('jas', 'Иакова'),
  BibleBook('1pe', '1-е Петра'),
  BibleBook('2pe', '2-е Петра'),
  BibleBook('1jn', '1-е Иоанна'),
  BibleBook('2jn', '2-е Иоанна'),
  BibleBook('3jn', '3-е Иоанна'),
  BibleBook('jud', 'Иуды'),
  BibleBook('rim', 'К Римлянам'),
  BibleBook('1co', '1-е Коринфянам'),
  BibleBook('2co', '2-е Коринфянам'),
  BibleBook('gal', 'К Галатам'),
  BibleBook('eph', 'К Ефесянам'),
  BibleBook('flp', 'К Филиппийцам'),
  BibleBook('col', 'К Колоссянам'),
  BibleBook('1th', '1-е Фессалоникийцам'),
  BibleBook('2th', '2-е Фессалоникийцам'),
  BibleBook('1ti', '1-е Тимофею'),
  BibleBook('2ti', '2-е Тимофею'),
  BibleBook('tit', 'К Титу'),
  BibleBook('phm', 'К Филимону'),
  BibleBook('heb', 'К Евреям'),
  BibleBook('rev', 'Откровение'),
];

/// Быстрый доступ к названию книги по коду.
final Map<String, String> kBookNameByCode = {
  for (final b in kBibleBooks) b.code: b.name,
};

String bookName(String code) => kBookNameByCode[code] ?? code;

/// Позиция книги в каноническом порядке ([kBibleBooks]).
final Map<String, int> kBookIndexByCode = {
  for (var i = 0; i < kBibleBooks.length; i++) kBibleBooks[i].code: i,
};

/// Индекс книги для сортировки. Неизвестный код уходит в конец, а не в начало.
int bookIndex(String code) => kBookIndexByCode[code] ?? kBibleBooks.length;

/// Граница заветов — берём от кода первой книги НЗ, а не числом: список книг
/// может поменяться.
final int _firstNewTestamentIndex = kBookIndexByCode['mf']!;

bool isNewTestament(String code) => bookIndex(code) >= _firstNewTestamentIndex;

bool isPsalms(String code) => code == 'ps';
