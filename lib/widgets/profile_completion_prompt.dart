import 'package:flutter/material.dart';

import '../data/church_repository.dart';
import '../models/church.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/triad_service.dart';

/// Просьба выбрать церковь и/или указать телефон — для тех, кто это не
/// сделал при регистрации (аккаунты до этих полей, либо церковь потом
/// сбросили). Без церкви не видно ни графика, ни тройки, поэтому просим
/// заполнить модальным окном при каждом запуске, а не мягкой плашкой сбоку:
/// такую легко не заметить и продолжить пользоваться пустым приложением.
/// «Напомнить позже» закрывает окно только до следующего запуска — как и
/// проверка обновлений.
class ProfileCompletionPrompt extends StatefulWidget {
  const ProfileCompletionPrompt({super.key});

  @override
  State<ProfileCompletionPrompt> createState() =>
      _ProfileCompletionPromptState();
}

class _ProfileCompletionPromptState extends State<ProfileCompletionPrompt> {
  bool _asked = false;

  Future<void> _maybeShow() async {
    Map<String, dynamic>? profile;
    try {
      profile = await AuthService.instance.profile();
    } catch (_) {
      return;
    }
    if (!mounted || profile == null) return;

    final churchId = profile['churchId'] as String?;
    final needChurch = churchId == null || churchId.isEmpty;
    final needPhone = ((profile['phone'] as String?) ?? '').trim().isEmpty;
    if (!needChurch && !needPhone) return;

    List<Church> churches = const [];
    if (needChurch) {
      try {
        churches = await ChurchRepository.instance.allChurches();
      } catch (_) {
        churches = const [];
      }
    }
    if (!mounted) return;

    final phoneCtrl = TextEditingController();
    String? selectedChurch;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, setInner) => AlertDialog(
            icon: const Icon(Icons.person_pin_circle_outlined),
            title: const Text('Заполните профиль'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Без этих данных не видно ни графика, ни тройки.'),
                  const SizedBox(height: 16),
                  if (needChurch) ...[
                    if (churches.isEmpty)
                      Text(
                        'Не удалось загрузить список церквей — попробуйте '
                        'ещё раз позже.',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selectedChurch,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Церковь',
                          prefixIcon: Icon(Icons.church_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final c in churches)
                            DropdownMenuItem(
                                value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) => setInner(() => selectedChurch = v),
                        validator: (v) =>
                            v == null ? 'Выберите церковь' : null,
                      ),
                    if (needPhone) const SizedBox(height: 12),
                  ],
                  if (needPhone)
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Телефон',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                        helperText: 'Виден только вашей тройке и '
                            'администраторам церкви',
                        helperMaxLines: 2,
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Введите телефон';
                        final digits =
                            s.replaceAll(RegExp(r'[^0-9]'), '').length;
                        return digits < 10 ? 'Похоже, номер неполный' : null;
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Напомнить позже'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  // selectedChurch остаётся null, если список церквей не
                  // загрузился (поля выбора тогда просто нет в форме) — не
                  // пишем в этом случае, иначе диалог закроется, будто
                  // церковь выбрана, а на деле она так и не задана.
                  if (needChurch && selectedChurch != null) {
                    await AuthService.instance.setChurch(selectedChurch);
                    await ThemeService.instance.loadForCurrentUser();
                  }
                  if (needPhone) {
                    await AuthService.instance
                        .updateProfile(phone: phoneCtrl.text.trim());
                    await TriadService.instance.syncMyProfileToTriad();
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
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
