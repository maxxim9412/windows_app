import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/triad_service.dart';

/// Мягкая просьба указать телефон — для тех, кто регистрировался до того, как
/// мы стали его собирать. Не блокирует: можно нажать «Позже», и плашка уйдёт
/// до следующего запуска. У новых пользователей телефон уже есть — они её не
/// увидят.
class PhonePromptBanner extends StatefulWidget {
  const PhonePromptBanner({super.key});

  @override
  State<PhonePromptBanner> createState() => _PhonePromptBannerState();
}

class _PhonePromptBannerState extends State<PhonePromptBanner> {
  bool? _needsPhone; // null — ещё проверяем
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final p = await AuthService.instance.profile();
      final phone = ((p?['phone'] as String?) ?? '').trim();
      if (mounted) setState(() => _needsPhone = phone.isEmpty);
    } catch (_) {
      if (mounted) setState(() => _needsPhone = false); // не мешаем при ошибке
    }
  }

  Future<void> _addPhone() async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Телефон для связи'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Телефон',
              helperText: 'Виден только вашей тройке и администраторам',
              helperMaxLines: 2,
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Введите телефон';
              final digits = s.replaceAll(RegExp(r'[^0-9]'), '').length;
              return digits < 10 ? 'Похоже, номер неполный' : null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (saved != true) return;

    await AuthService.instance.updateProfile(phone: ctrl.text.trim());
    // Тройка держит копию телефона — обновляем и её.
    await TriadService.instance.syncMyProfileToTriad();
    if (mounted) setState(() => _needsPhone = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _needsPhone != true) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.phone_outlined,
                size: 18, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Добавьте телефон — по нему с вами свяжется тройка.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
            TextButton(
                onPressed: _addPhone, child: const Text('Добавить')),
            IconButton(
              tooltip: 'Позже',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _dismissed = true),
            ),
          ],
        ),
      ),
    );
  }
}
