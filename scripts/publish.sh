#!/usr/bin/env bash
# Публикация релиза.
#
#   Веб      → Firebase Hosting (bible-reflection.web.app), обновляется сам.
#   Манифест → там же update.json: версия + размер/md5 ожидаемого APK.
#   APK      → кладётся на рабочий стол; вы вручную заливаете его на Яндекс.Диск,
#              ЗАМЕНЯЯ старый файл (в Яндексе кнопка «Заменить»), чтобы ссылка
#              не менялась.
#
# Приложение показывает плашку обновления, только когда на Диске уже лежит файл
# с размером/md5 из манифеста — то есть после вашей загрузки, а не раньше.
#
# Перед запуском поднимите версию в pubspec.yaml (versionCode должен вырасти).
set -euo pipefail

cd "$(dirname "$0")/.."
FLUTTER=~/development/flutter/bin/flutter
AAPT="$(ls ~/Library/Android/sdk/build-tools/*/aapt2 | tail -1)"
APK=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Постоянная публичная ссылка на файл на Яндекс.Диске (вида
# https://disk.yandex.ru/d/XXXX). Пусто — манифест не публикуется, плашка
# обновления не показывается (безопасно, пока ссылки нет).
YANDEX_URL=""

echo "==> Сборка веба"
$FLUTTER build web --release

echo "==> Сборка APK"
$FLUTTER build apk --release --split-per-abi
cp "$APK" ~/Desktop/QT.apk

if [ -n "$YANDEX_URL" ]; then
  VCODE=$("$AAPT" dump badging "$APK" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")
  VNAME=$("$AAPT" dump badging "$APK" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
  SIZE=$(stat -f%z "$APK")
  MD5=$(md5 -q "$APK")
  cat > build/web/update.json <<JSON
{
  "versionCode": ${VCODE},
  "versionName": "${VNAME}",
  "url": "${YANDEX_URL}",
  "size": ${SIZE},
  "md5": "${MD5}"
}
JSON
  echo "==> Манифест: v${VNAME} code=${VCODE} size=${SIZE} md5=${MD5}"
else
  rm -f build/web/update.json
  echo "==> YANDEX_URL не задан — манифест пропущен (плашка обновления не активна)"
fi

echo "==> Деплой на хостинг"
firebase deploy --only hosting

echo
echo "==> Готово. APK: ~/Desktop/QT.apk"
if [ -n "$YANDEX_URL" ]; then
  echo "    Залейте его на Яндекс.Диск, ЗАМЕНИВ старый файл (ссылка сохранится)."
  echo "    Плашка появится у людей, когда на Диске окажется именно этот файл."
fi
