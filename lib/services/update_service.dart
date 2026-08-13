import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Доступное обновление сайдлоад-сборки (Android APK, macOS DMG или Windows
/// установщик).
class UpdateInfo {
  const UpdateInfo({required this.versionName, required this.downloadUrl});
  final String versionName;
  final String downloadUrl;
}

/// Проверка обновлений для сайдлоад-версий (Android APK, macOS DMG, Windows
/// установщик — все вне магазинов, сами не обновляются).
///
/// Схема: манифест [_manifestUrl] лежит на нашем хостинге (публикуется при
/// каждой сборке) и содержит отдельный раздел на каждую платформу — номера
/// сборок не сравнимы между собой (у Android versionCode со смещением по
/// ABI, у остальных — обычный номер сборки из pubspec). Сам файл — на
/// Яндекс.Диске по постоянной ссылке, которую владелец заменяет вручную.
/// Между «объявили новую версию» и «залили новый файл» есть окно: чтобы не
/// отправить человека качать ещё старый файл, перед показом плашки сверяем
/// файл по ссылке (размер и md5) с тем, что записано в манифесте. Не
/// совпало — значит на Диске пока старое, молчим.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const _manifestUrl = 'https://bible-reflection.web.app/update.json';
  static const _yandexApi =
      'https://cloud-api.yandex.net/v1/disk/public/resources';

  /// Ключ раздела манифеста для текущей платформы. null — для этой платформы
  /// сборки не публикуются (сравнивать не с чем).
  String? _platformKey() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      default:
        return null;
    }
  }

  /// Вернёт обновление, только если версия на сервере новее установленной И файл
  /// по ссылке — уже новый. В вебе всегда null (там приложение обновляется само).
  /// Никогда не бросает: не смогли проверить — просто не показываем плашку.
  Future<UpdateInfo?> check() async {
    if (kIsWeb) return null;
    final platformKey = _platformKey();
    if (platformKey == null) return null;
    try {
      final data = await _getJson(Uri.parse(_manifestUrl));
      if (data == null) return null;
      final platformData = data[platformKey] as Map<String, dynamic>?;
      if (platformData == null) return null;

      final latest = (platformData['versionCode'] as num?)?.toInt();
      final url = platformData['url'] as String?;
      if (latest == null || url == null || url.isEmpty) return null;

      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      if (latest <= current) return null; // уже стоит свежая

      // Версия новее — но лежит ли на Диске уже новый файл?
      final expectedSize = (platformData['size'] as num?)?.toInt();
      final expectedMd5 = platformData['md5'] as String?;
      if (!await _fileReady(url, expectedSize, expectedMd5)) return null;

      return UpdateInfo(
        versionName: (platformData['versionName'] as String?) ?? '',
        downloadUrl: url,
      );
    } catch (_) {
      return null;
    }
  }

  /// Совпадает ли файл на Яндекс.Диске с ожидаемой сборкой. Спрашиваем метаданные
  /// публичного ресурса (размер и md5) — качать 114 МБ ради проверки не нужно.
  /// Токен не требуется: ресурс публичный.
  Future<bool> _fileReady(String publicUrl, int? size, String? md5) async {
    if (size == null && md5 == null) return true; // нечего сверять
    final uri = Uri.parse(_yandexApi).replace(queryParameters: {
      'public_key': publicUrl,
      'fields': 'size,md5',
    });
    final meta = await _getJson(uri);
    if (meta == null) return false; // не проверили — лучше не показывать
    final actualSize = (meta['size'] as num?)?.toInt();
    final actualMd5 = meta['md5'] as String?;
    if (size != null && actualSize != size) return false;
    if (md5 != null && actualMd5 != null && actualMd5 != md5) return false;
    return true;
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.getUrl(uri);
      final resp = await req.close().timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } finally {
      client.close(force: true);
    }
  }
}
