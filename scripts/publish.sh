#!/usr/bin/env bash
# Публикация релиза: веб + APK на хостинг под ОДНОЙ постоянной ссылкой.
#
#   https://bible-reflection.web.app          — веб-версия (обновляется сама)
#   https://bible-reflection.web.app/QT.apk   — Android APK (ссылка постоянная)
#   https://bible-reflection.web.app/update.json — манифест для проверки обновлений
#
# Манифест содержит versionCode из СОБРАННОГО APK, поэтому приложение точно
# знает, новее ли версия на сервере. Версию в pubspec.yaml поднять ДО запуска.
set -euo pipefail

cd "$(dirname "$0")/.."
FLUTTER=~/development/flutter/bin/flutter
AAPT="$(ls ~/Library/Android/sdk/build-tools/*/aapt2 | tail -1)"
APK=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

echo "==> Сборка веба"
$FLUTTER build web --release

echo "==> Сборка APK"
$FLUTTER build apk --release --split-per-abi

echo "==> Копирую APK: на рабочий стол и в раздачу"
cp "$APK" ~/Desktop/QT.apk
cp "$APK" build/web/QT.apk

echo "==> Манифест обновления из реального versionCode APK"
VCODE=$("$AAPT" dump badging "$APK" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")
VNAME=$("$AAPT" dump badging "$APK" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
cat > build/web/update.json <<JSON
{
  "versionCode": ${VCODE},
  "versionName": "${VNAME}",
  "url": "https://bible-reflection.web.app/QT.apk"
}
JSON
echo "    versionCode=${VCODE} versionName=${VNAME}"

echo "==> Деплой на хостинг"
firebase deploy --only hosting

echo "==> Готово. APK: https://bible-reflection.web.app/QT.apk (v${VNAME}, code ${VCODE})"
