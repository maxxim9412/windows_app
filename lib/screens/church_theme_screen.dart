import 'package:flutter/material.dart';

import '../data/church_repository.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../utils/app_themes.dart';

/// Выбор основного цвета оформления для прихожан церкви. Доступен админу церкви
/// и супер-админу.
class ChurchThemeScreen extends StatefulWidget {
  const ChurchThemeScreen({
    super.key,
    required this.churchId,
    required this.churchName,
    this.currentSeed,
  });

  final String churchId;
  final String churchName;
  final int? currentSeed;

  @override
  State<ChurchThemeScreen> createState() => _ChurchThemeScreenState();
}

class _ChurchThemeScreenState extends State<ChurchThemeScreen> {
  late int _selected = widget.currentSeed ?? kDefaultSeed;
  bool _saving = false;

  Future<void> _save(int seed) async {
    setState(() {
      _selected = seed;
      _saving = true;
    });
    try {
      await ChurchRepository.instance.setThemeColor(widget.churchId, seed);
      // Перекрашиваем сразу, но только если это моя церковь: супер-админ может
      // настраивать чужую, и его приложение меняться не должно.
      final myChurch = await AuthService.instance.currentChurchId();
      if (myChurch == widget.churchId) ThemeService.instance.apply(seed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оформление сохранено.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _selected = widget.currentSeed ?? kDefaultSeed);
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
            'Основной цвет увидят все прихожане этой церкви — на телефоне и в '
            'браузере. Тёмная тема подстроится сама.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 20),

          // Палитра.
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final c in kThemeColors)
                _swatch(theme, c.seed, c.name, _selected == c.seed),
            ],
          ),

          const SizedBox(height: 28),
          Text('Как будет выглядеть', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _Preview(scheme: ColorScheme.fromSeed(seedColor: Color(_selected))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _swatch(ThemeData theme, int seed, String name, bool selected) {
    return GestureDetector(
      onTap: _saving ? null : () => _save(seed),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Color(seed),
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                  : Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 24)
                : null,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(name,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}

/// Макет экрана QT в выбранном цвете. Схема настоящая (Material 3) — то же, что
/// увидят прихожане.
class _Preview extends StatelessWidget {
  const _Preview({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('QT (Тихое время)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface)),
              Icon(Icons.calendar_month_outlined,
                  size: 16, color: scheme.onSurface),
            ],
          ),
          const SizedBox(height: 8),
          Text('вторник, 15 июля',
              style: TextStyle(fontSize: 12, color: scheme.primary)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('От Иоанна 3:16',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text('Ибо так возлюбил Бог мир, что отдал Сына Своего…',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: scheme.onSurface)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text('Сохранить',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onPrimary)),
          ),
        ],
      ),
    );
  }
}
