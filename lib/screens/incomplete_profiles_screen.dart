import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/church_repository.dart';
import '../data/report_repository.dart';
import '../utils/app_dimens.dart';
import '../utils/date_helpers.dart';

/// Супер-админ: кто зарегистрировался, но не выбрал церковь и/или не указал
/// телефон. Такие профили не видны ни в одном отчёте по церкви — они там
/// просто не встречаются, поскольку у них нет churchId.
class IncompleteProfilesScreen extends StatefulWidget {
  const IncompleteProfilesScreen({super.key});

  @override
  State<IncompleteProfilesScreen> createState() =>
      _IncompleteProfilesScreenState();
}

class _IncompleteProfilesScreenState extends State<IncompleteProfilesScreen> {
  late Future<List<IncompleteProfile>> _future =
      ReportRepository.instance.incompleteProfiles();
  Map<String, String> _churchNames = {};

  @override
  void initState() {
    super.initState();
    ChurchRepository.instance.streamChurches().first.then((churches) {
      if (!mounted) return;
      setState(() => _churchNames = {for (final c in churches) c.id: c.name});
    });
  }

  void _reload() =>
      setState(() => _future = ReportRepository.instance.incompleteProfiles());

  void _copy(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Без церкви / телефона'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<IncompleteProfile>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text('Не удалось загрузить список: ${snap.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final people = snap.data ?? const [];
          if (people.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  'Таких нет: у всех зарегистрированных есть и церковь, '
                  'и телефон.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: people.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _row(theme, people[i]),
          );
        },
      ),
    );
  }

  Widget _row(ThemeData theme, IncompleteProfile p) {
    final primary = p.phone.isNotEmpty ? p.phone : p.email;
    final label =
        p.phone.isNotEmpty ? 'Телефон скопирован' : 'Почта скопирована';
    final missing = [
      if (p.missingChurch) 'без церкви',
      if (p.missingPhone) 'без телефона',
    ].join(', ');
    final churchNote =
        p.missingChurch ? missing : '$missing · ${_churchNames[p.churchId] ?? p.churchId}';
    return InkWell(
      onTap: primary.isEmpty ? null : () => _copy(primary, label),
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.displayName, style: theme.textTheme.bodyMedium),
                  if (p.email.isNotEmpty)
                    Text(p.email,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  if (p.phone.isNotEmpty)
                    Text(p.phone,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 2),
                  Text(churchNote,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error)),
                  if (p.createdAt != null)
                    Text('Регистрация: ${humanDateShort(p.createdAt!)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
            if (primary.isNotEmpty)
              Icon(Icons.copy_outlined,
                  size: 16, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}
