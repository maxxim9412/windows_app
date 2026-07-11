# Размышления над Библией

Приложение (Flutter, Android + iOS) для размышления над отрывком из Библии:
**отрывок дня → личные заметки → напоминания по будням.**

Синодальный перевод, офлайн. Это **MVP (этап 1)** — один пользователь.
Обмен заметками в тройке и видеозвонки — этапы 2 и 3 (см. «Дорожную карту»).

---

## Что уже есть в коде

- **Отрывок дня** — на каждый будний день свой адрес (Книга, глава, стихи),
  текст подтягивается из локальной базы перевода.
- **Заметки** — окно для размышлений на каждый день, автосохранение, история заметок.
- **Напоминания** — включаются в настройках, будни (Пн–Пт) в выбранное время.
- **Экран администратора** — назначение отрывков на дни: выбираешь дату, книгу,
  главу и диапазон стихов; сразу видно предпросмотр текста из базы.
- При первом запуске подсеваются 5 примеров отрывков на ближайшие будни.

## Структура

```
lib/
  main.dart                     точка входа (инициализация)
  app.dart                      тема и корневой экран
  models/                       Passage, Note
  data/
    db.dart                     локальная SQLite (заметки + расписание)
    bible_repository.dart       чтение текста перевода из ассета
    passage_repository.dart     расписание отрывков по дням
    notes_repository.dart       личные заметки
  services/
    notification_service.dart   локальные напоминания (flutter_local_notifications)
    settings_service.dart       настройки (время/включённость)
  screens/                      home / notes_list / admin / settings
  utils/                        список книг, работа с датами
assets/bible/synodal_sample.json  ОБРАЗЕЦ базы (несколько отрывков)
```

---

## Как запустить (macOS, с нуля)

На этой машине пока нет ни Flutter, ни Android Studio, ни Xcode. Порядок:

### 1. Установить Flutter SDK (без Homebrew)
```bash
cd ~/development            # или любая папка
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/development/flutter/bin"   # добавь в ~/.zshrc
flutter --version
```

### 2. Android (быстрее для старта, iOS можно позже)
1. Скачай **Android Studio**: https://developer.android.com/studio
2. При первом запуске установи Android SDK, командную строку и эмулятор.
3. Прими лицензии и проверь окружение:
   ```bash
   flutter doctor --android-licenses
   flutter doctor
   ```

### 3. iOS (позже, требует Xcode)
- Установи **Xcode** из App Store (большой), затем:
  ```bash
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -runFirstLaunch
  ```

### 4. Сгенерировать платформенные папки и запустить
В корне проекта (`~/Desktop/bible_reflection`):
```bash
flutter create .           # создаст android/ ios/ и пр., НЕ трогая lib/ и assets/
flutter pub get
flutter run                # на подключённом устройстве или эмуляторе
```

> `flutter create .` может перезаписать `pubspec.yaml` и `lib/main.dart`.
> Проект под git — если это случится, верни их: `git checkout pubspec.yaml lib/main.dart`.

---

## Подключить полный Синодальный перевод

Сейчас в `assets/bible/synodal_sample.json` лежит только **образец** (5 отрывков),
чтобы приложение работало сразу. Для полного текста:

1. Возьми Синодальный перевод в JSON (общественное достояние; например, репозитории
   `scrollmapper/bible_databases` или аналогичные открытые наборы).
2. Приведи к формату:
   ```json
   { "books": { "<код>": { "name": "...", "chapters": { "<глава>": { "<стих>": "текст" } } } } }
   ```
   Коды книг — в `lib/utils/bible_books.dart` (`gen`, `exo`, … `jn`, `rim`, `rev`).
3. Замени `assets/bible/synodal_sample.json` (или добавь `synodal_full.json`
   и поменяй `_assetPath` в `lib/data/bible_repository.dart`).

> Полный перевод — ~4–5 МБ. Для скорости можно позже перевести базу в SQLite,
> сейчас JSON достаточно.

---

## Дорожная карта

- **Этап 1 (этот код):** отрывок дня + заметки + напоминания. Один пользователь, всё локально.
- **Этап 2 — тройка и обмен заметками:**
  - Бэкенд: **Firebase** (Auth + Firestore + Cloud Messaging).
  - Аккаунты, «круг» из 3 человек по приглашению, синхронизация заметок,
    просмотр заметок участников по каждому дню.
- **Этап 3 — видеозвонки втроём:**
  - **Jitsi** (быстрее всего, без своего медиасервера) или **LiveKit** (гибче).
  - Кнопка «Позвонить» в круге, звонок на троих через интернет.
