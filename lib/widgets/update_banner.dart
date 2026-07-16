import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';

/// Плашка «доступно обновление» для Android-версии. Появляется сверху, если на
/// сервере версия новее. Кнопка открывает ссылку на APK — установить всё равно
/// нужно вручную (Android не даёт ставить не из Play молча), но человек хотя бы
/// узнаёт, что вышло обновление, и попадает на загрузку в одно нажатие.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  // Не в build: проверка должна пройти один раз, а не на каждой перерисовке.
  final Future<UpdateInfo?> _check = UpdateService.instance.check();
  bool _dismissed = false;

  Future<void> _download(String url) async {
    // Внешним браузером: он скачает APK и предложит установить.
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return FutureBuilder<UpdateInfo?>(
      future: _check,
      builder: (context, snap) {
        final info = snap.data;
        if (info == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(Icons.system_update,
                    size: 20, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info.versionName.isEmpty
                        ? 'Доступна новая версия приложения'
                        : 'Доступна версия ${info.versionName}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                TextButton(
                  onPressed: () => _download(info.downloadUrl),
                  child: const Text('Обновить'),
                ),
                IconButton(
                  tooltip: 'Позже',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _dismissed = true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
