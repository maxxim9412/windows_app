import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Доступное обновление Android-приложения.
class UpdateInfo {
  const UpdateInfo({required this.versionName, required this.apkUrl});
  final String versionName;
  final String apkUrl;
}

/// Проверка обновлений для сайдлоад-версии (APK не из Play, сам не обновляется).
///
/// Сверяет свой versionCode с манифестом на хостинге. Манифест кладётся туда
/// при каждой публикации (см. scripts/publish.sh) и содержит versionCode
/// собранного APK и ссылку на него.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const _manifestUrl = 'https://bible-reflection.web.app/update.json';

  /// Вернёт обновление, если на сервере версия новее установленной. В вебе
  /// всегда null: там приложение обновляется само, и ставить APK незачем.
  /// Никогда не бросает — не смогли проверить, просто не показываем плашку.
  Future<UpdateInfo?> check() async {
    if (kIsWeb) return null;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(Uri.parse(_manifestUrl));
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final latest = (data['versionCode'] as num?)?.toInt();
      final url = data['url'] as String?;
      if (latest == null || url == null) return null;

      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      if (latest <= current) return null;

      return UpdateInfo(
        versionName: (data['versionName'] as String?) ?? '',
        apkUrl: url,
      );
    } catch (_) {
      return null;
    }
  }
}
