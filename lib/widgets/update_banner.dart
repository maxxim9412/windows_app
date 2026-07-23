import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';

/// Проверка обновления для Android-версии. Ничего не рисует сама — если на
/// сервере версия новее, поверх всего приложения показывает модальное окно
/// с кнопками «Обновить» / «Пока пропустить». Проверка идёт заново при каждом
/// запуске приложения (состояние не хранится), так что если пропустить —
/// окно вернётся при следующем открытии.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _asked = false;

  Future<void> _download(String url) async {
    // Внешним браузером: он скачает APK и предложит установить.
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _maybeShow() async {
    final info = await UpdateService.instance.check();
    if (!mounted || info == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.system_update),
          title: const Text('Доступно обновление'),
          content: Text(
            info.versionName.isEmpty
                ? 'Вышла новая версия приложения.'
                : 'Вышла версия ${info.versionName}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Пока пропустить'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _download(info.downloadUrl);
              },
              child: const Text('Обновить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_asked) {
      _asked = true;
      // После первого кадра: диалогу нужен готовый Navigator над этим виджетом.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }
    return const SizedBox.shrink();
  }
}
