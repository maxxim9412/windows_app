# Установка окружения (macOS, Apple M1)

Пошагово, с нуля. Твои вводные: **Apple Silicon (M1)**, **macOS 26**, Command Line
Tools уже установлены. Ориентировочно займёт **1.5–3 часа** (в основном — загрузки).

Порядок: сначала общее → Flutter → Android (для быстрого старта) → iOS (можно позже).
Каждый шаг помечен: **[обязательно]** или **[позже]**.

---

## Шаг 0. Подготовка

### 0.1 Rosetta 2 — [обязательно на Apple Silicon]
Часть инструментов Android/iOS всё ещё x86. Ставим слой совместимости:
```bash
sudo softwareupdate --install-rosetta --agree-to-license
```

### 0.2 Homebrew — [рекомендую]
Менеджер пакетов. Сильно упрощает установку CocoaPods и утилит.
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
После установки терминал подскажет две команды вида `echo ... >> ~/.zprofile` и
`eval "$(/opt/homebrew/bin/brew shellenv)"` — **выполни их**, затем проверь:
```bash
brew --version
```

---

## Шаг 1. Flutter SDK — [обязательно]

Скачиваем через git (git уже есть) в домашнюю папку:
```bash
mkdir -p ~/development
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable
```

### 1.1 Добавить Flutter в PATH
```bash
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```
Проверка (первый запуск скачает недостающее, подожди минуту):
```bash
flutter --version
```

---

## Шаг 2. Android — [обязательно для старта]

Android быстрее в настройке, чем iOS, и не требует Xcode. Начни с него.

### 2.1 Установить Android Studio
1. Скачай **Android Studio** (Apple Silicon / .dmg):
   https://developer.android.com/studio
2. Перетащи в «Программы», запусти, пройди **Setup Wizard** (выбор «Standard»).
   Он сам скачает: Android SDK, платформенные инструменты и системный образ эмулятора.

### 2.2 Указать Flutter путь к Android SDK (обычно не нужно, но на всякий)
```bash
flutter config --android-sdk "$HOME/Library/Android/sdk"
```

### 2.3 Принять лицензии Android
```bash
flutter doctor --android-licenses
```
Отвечай `y` на все вопросы.

### 2.4 Создать эмулятор (или подключить телефон)
**Вариант А — эмулятор:** в Android Studio → значок «More Actions» →
**Virtual Device Manager** → Create Device → выбери, напр., Pixel 7 → системный образ
(например, последний стабильный) → Finish. Запусти эмулятор кнопкой ▶.

**Вариант Б — реальный телефон Android:**
1. Настройки телефона → «О телефоне» → 7 раз тапни по «Номер сборки» (включит режим
   разработчика).
2. В «Для разработчиков» включи **Отладку по USB**.
3. Подключи телефон кабелем, разреши отладку во всплывающем окне.

---

## Шаг 3. iOS — [позже, когда захочешь собрать под iPhone]

Требует Xcode (~15 ГБ) — можно отложить и сначала погонять на Android.

### 3.1 Установить Xcode
Из **App Store** → «Xcode» → Установить (долго). Затем:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

### 3.2 CocoaPods (менеджер зависимостей iOS)
С Homebrew (проще всего на M1):
```bash
brew install cocoapods
```
Проверка: `pod --version`

### 3.3 Симулятор iPhone
Открывается командой:
```bash
open -a Simulator
```

---

## Шаг 4. Проверка окружения — [обязательно]

```bash
flutter doctor -v
```
Цель — зелёные галочки у **Flutter**, **Android toolchain** и (позже) **Xcode**.
Пункты про «Chrome» и «VS Code» не критичны. Что покажет красным — устрани по
подсказке из вывода.

---

## Шаг 5. Запуск проекта — [обязательно]

```bash
cd ~/Desktop/bible_reflection

# 1) Сгенерировать платформенные папки (android/, ios/ и пр.)
flutter create .

# 2) Вернуть файлы, если flutter create их перезаписал (проект под git)
git checkout pubspec.yaml lib/main.dart

# 3) Скачать зависимости
flutter pub get

# 4) Посмотреть доступные устройства (эмулятор/телефон должен быть запущен)
flutter devices

# 5) Запустить
flutter run
```
Горячая перезагрузка во время `flutter run`: клавиша **r** (быстро), **R** (полный
рестарт), **q** (выход).

> После `flutter create .` не забудь платформенную настройку уведомлений
> из **README.md**, раздел «Платформенная настройка для напоминаний».

---

## Возможные проблемы

- **`flutter: command not found`** — не подхватился PATH. Открой новый терминал или
  выполни `source ~/.zshrc`.
- **`flutter doctor` ругается на Android licenses** — повтори
  `flutter doctor --android-licenses`, отвечай `y`.
- **`CocoaPods not installed`** — только для iOS; см. шаг 3.2.
- **Эмулятор Android не виден в `flutter devices`** — сначала запусти его в Android
  Studio (Virtual Device Manager → ▶), потом повтори команду.
- **Первый `flutter run` долгий** — нормально, идёт сборка Gradle/индексация. Дальше
  быстрее.
- **Сборка падает на версии пакета** — пришли мне вывод ошибки, поправлю
  ограничение версии в `pubspec.yaml`.
