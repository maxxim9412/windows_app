import 'package:flutter/material.dart';

import '../data/church_repository.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../utils/app_themes.dart';

/// Выбор оформления для прихожан церкви. Доступен админу церкви и супер-админу.
class ChurchThemeScreen extends StatefulWidget {
  const ChurchThemeScreen({
    super.key,
    required this.churchId,
    required this.churchName,
    this.currentThemeId,
  });

  final String churchId;
  final String churchName;
  final String? currentThemeId;

  @override
  State<ChurchThemeScreen> createState() => _ChurchThemeScreenState();
}

class _ChurchThemeScreenState extends State<ChurchThemeScreen> {
  late String _selected = themeById(widget.currentThemeId).id;
  bool _saving = false;

  Future<void> _save(String id) async {
    setState(() {
      _selected = id;
      _saving = true;
    });
    try {
      await ChurchRepository.instance.setTheme(widget.churchId, id);
      // Перекрашиваем сразу, но только если это моя церковь: супер-админ может
      // настраивать чужую, и его приложение меняться не должно.
      final myChurch = await AuthService.instance.currentChurchId();
      if (myChurch == widget.churchId) ThemeService.instance.apply(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оформление сохранено.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _selected = themeById(widget.currentThemeId).id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Оформление церкви')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.churchName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Выбранное оформление увидят все прихожане этой церкви — '
            'на телефоне и в браузере. Тёмная тема подстроится сама.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          for (final t in kAppThemes) ...[
            _ThemeCard(
              appTheme: t,
              selected: _selected == t.id,
              onTap: _saving ? null : () => _save(t.id),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.appTheme,
    required this.selected,
    required this.onTap,
  });

  final AppTheme appTheme;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(appTheme.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(appTheme.description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
            const SizedBox(height: 12),
            _Preview(scheme: appTheme.scheme(Brightness.light)),
          ],
        ),
      ),
    );
  }
}

/// Макет экрана QT в предлагаемой палитре. Цвета берутся из настоящей схемы,
/// сгенерированной Material 3, — то же, что увидят прихожане.
class _Preview extends StatelessWidget {
  const _Preview({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('QT (Тихое время)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface)),
              Icon(Icons.calendar_month_outlined,
                  size: 14, color: scheme.onSurface),
            ],
          ),
          const SizedBox(height: 8),
          Text('вторник, 15 июля',
              style: TextStyle(fontSize: 11, color: scheme.primary)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('От Иоанна 3:16',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text('Ибо так возлюбил Бог мир, что отдал Сына Своего…',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: scheme.onSurface)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text('Сохранено',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: scheme.onPrimary)),
          ),
        ],
      ),
    );
  }
}
