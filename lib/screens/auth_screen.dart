import 'package:flutter/material.dart';

import '../data/church_repository.dart';
import '../models/church.dart';
import '../services/auth_service.dart';

/// Вход и регистрация по email + паролю.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _isRegister = false;
  bool _busy = false;
  String? _error;

  List<Church> _churches = const [];
  String? _churchId;

  @override
  void initState() {
    super.initState();
    _loadChurches();
  }

  Future<void> _loadChurches() async {
    try {
      final list = await ChurchRepository.instance.allChurches();
      if (mounted) setState(() => _churches = list);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isRegister) {
        await AuthService.instance.register(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          name: _nameCtrl.text,
          phone: _phoneCtrl.text,
          churchId: _churchId,
        );
      } else {
        await AuthService.instance.signIn(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
      }
      // Дальше AuthGate сам покажет приложение.
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Введите почту — на неё придёт письмо для сброса.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Письмо для сброса отправлено на $email')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.menu_book,
                        size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Размышления над Библией',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      _isRegister ? 'Создание аккаунта' : 'Вход',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 24),
                    if (_isRegister)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Имя',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Введите имя'
                              : null,
                        ),
                      ),
                    if (_isRegister)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _phoneCtrl,
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
                            // Не придираемся к формату — записи бывают разные,
                            // важно лишь, чтобы по номеру можно было позвонить.
                            final digits =
                                s.replaceAll(RegExp(r'[^0-9]'), '').length;
                            return digits < 10 ? 'Похоже, номер неполный' : null;
                          },
                        ),
                      ),
                    if (_isRegister)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        // Церковь обязательна: от неё зависит и график отрывков,
                        // и тройка (она может быть только из одной церкви).
                        child: DropdownButtonFormField<String>(
                          initialValue: _churchId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Церковь',
                            prefixIcon: Icon(Icons.church_outlined),
                            border: OutlineInputBorder(),
                            helperText: 'Отрывки и тройка — внутри вашей церкви',
                          ),
                          items: [
                            for (final c in _churches)
                              DropdownMenuItem(value: c.id, child: Text(c.name)),
                          ],
                          onChanged: (v) => setState(() => _churchId = v),
                          validator: (v) =>
                              v == null ? 'Выберите церковь' : null,
                        ),
                      ),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Почта',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Введите почту' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Минимум 6 символов'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isRegister ? 'Зарегистрироваться' : 'Войти'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _isRegister = !_isRegister;
                                _error = null;
                              }),
                      child: Text(_isRegister
                          ? 'Уже есть аккаунт? Войти'
                          : 'Нет аккаунта? Зарегистрироваться'),
                    ),
                    if (!_isRegister)
                      TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: const Text('Забыли пароль?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
