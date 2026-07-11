#!/usr/bin/env bash
#
# Полуавтоматическая настройка окружения Flutter для проекта bible_reflection.
# Автоматизирует всё, что НЕ требует пароля sudo и GUI-приложений:
#   - установка Flutter SDK (git clone в ~/development)
#   - добавление Flutter в PATH (~/.zshrc)
#   - генерация платформенных папок проекта (flutter create .)
#   - восстановление наших файлов и flutter pub get
#   - flutter doctor
#
# Запуск (в ОБЫЧНОМ Терминале, где есть интернет):
#   cd ~/Desktop/bible_reflection
#   bash setup_flutter.sh
#
# Скрипт идемпотентный — можно запускать повторно.

set -e

FLUTTER_DIR="$HOME/development/flutter"
PROJECT_DIR="$HOME/Desktop/bible_reflection"
ZSHRC="$HOME/.zshrc"

say()  { printf "\n\033[1;34m==> %s\033[0m\n" "$1"; }
ok()   { printf "\033[1;32m  ✓ %s\033[0m\n" "$1"; }
warn() { printf "\033[1;33m  ! %s\033[0m\n" "$1"; }

# --- Проверка интернета ---------------------------------------------------
say "Проверяю доступ в интернет"
if ! git ls-remote --heads https://github.com/flutter/flutter.git stable >/dev/null 2>&1; then
  warn "Нет доступа к github.com. Проверь интернет и запусти скрипт снова."
  exit 1
fi
ok "Интернет есть"

# --- 1. Flutter SDK -------------------------------------------------------
if [ -x "$FLUTTER_DIR/bin/flutter" ]; then
  ok "Flutter уже установлен: $FLUTTER_DIR"
else
  say "Скачиваю Flutter SDK (несколько минут)"
  mkdir -p "$HOME/development"
  git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
  ok "Flutter склонирован"
fi

# --- 2. PATH --------------------------------------------------------------
export PATH="$PATH:$FLUTTER_DIR/bin"
if grep -q 'development/flutter/bin' "$ZSHRC" 2>/dev/null; then
  ok "PATH уже прописан в ~/.zshrc"
else
  say "Прописываю Flutter в PATH (~/.zshrc)"
  echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> "$ZSHRC"
  ok "Добавлено в ~/.zshrc (в новых терминалах подхватится автоматически)"
fi

# --- 3. Первый запуск Flutter (докачивает свои инструменты) ---------------
say "Инициализирую Flutter (flutter --version)"
flutter --version

# --- 4. Генерация проекта -------------------------------------------------
cd "$PROJECT_DIR"
say "Генерирую платформенные папки (flutter create .)"
flutter create . >/dev/null
ok "android/ ios/ и пр. созданы"

say "Возвращаю наши файлы, если flutter create их перезаписал"
git checkout pubspec.yaml lib/main.dart 2>/dev/null && ok "pubspec.yaml и lib/main.dart восстановлены" || warn "git checkout пропущен"

say "Скачиваю зависимости (flutter pub get)"
flutter pub get

# --- 5. Диагностика -------------------------------------------------------
say "Проверка окружения (flutter doctor)"
flutter doctor || true

# --- Итог -----------------------------------------------------------------
cat <<'EOF'

============================================================
Готово с автоматической частью. Что осталось СДЕЛАТЬ ВРУЧНУЮ:

  1. [sudo] Rosetta 2 (для Apple Silicon):
       sudo softwareupdate --install-rosetta --agree-to-license

  2. [GUI] Android Studio — скачать и пройти Setup Wizard:
       https://developer.android.com/studio
     затем принять лицензии:
       flutter doctor --android-licenses
     и создать эмулятор (Virtual Device Manager) или подключить
     телефон с включённой отладкой по USB.

  3. [позже, для iPhone] Xcode из App Store, затем:
       sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
       sudo xcodebuild -runFirstLaunch

  4. Добавить платформенные настройки уведомлений — см. README.md,
     раздел «Платформенная настройка для напоминаний».

  5. Запустить приложение (когда эмулятор/телефон готов):
       cd ~/Desktop/bible_reflection
       flutter devices
       flutter run
============================================================
EOF
