import 'dart:async';

import 'package:flutter/material.dart';

import '../data/bible_repository.dart';
import '../data/notes_repository.dart';
import '../data/passage_repository.dart';
import '../data/progress_repository.dart';
import '../models/passage.dart';
import '../services/auth_service.dart';
import '../services/selected_day.dart';
import '../utils/date_helpers.dart';
import '../utils/note_questions.dart';
import '../widgets/catch_up_banner.dart';
import '../widgets/progress_calendar_button.dart';
import 'notes_list_screen.dart';
import 'settings_screen.dart';
import '../utils/app_dimens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<TextEditingController> _controllers =
      List.generate(kNoteFieldCount, (_) => TextEditingController());

  /// Открытый день — общий с экраном «Чтение» (см. [SelectedDay]).
  DateTime _day = SelectedDay.instance.value;

  Passage? _passage;
  List<({int verse, String text})> _verses = const [];
  bool _loading = true;
  bool _dirty = false; // есть правки, ещё не записанные в хранилище
  bool _saving = false;
  // «Сохранено» показываем только как отклик на нажатие кнопки, а не на тихое
  // автосохранение — иначе кнопка сама менялась через секунду после набора
  // текста, и было непонятно, сохранил ли её вообще кто-то.
  bool _justSaved = false;
  bool _hasChurch = false;
  Timer? _debounce;

  bool get _hasText => _controllers.any((c) => c.text.trim().isNotEmpty);

  bool get _isToday => _day == SelectedDay.today;

  @override
  void initState() {
    super.initState();
    SelectedDay.instance.addListener(_onDayChanged);
    _load();
  }

  @override
  void dispose() {
    SelectedDay.instance.removeListener(_onDayChanged);
    _debounce?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Смена дня. Сначала дописываем незаписанные правки в СТАРЫЙ день: таймер
  /// автосохранения иначе сработал бы уже после переключения и записал бы текст
  /// в чужую дату.
  Future<void> _onDayChanged() async {
    _debounce?.cancel();
    if (_dirty) await _saveNote();
    if (!mounted) return;
    setState(() => _day = SelectedDay.instance.value);
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final churchId = await AuthService.instance.currentChurchId();
    final passage = await PassageRepository.instance.forDate(_day);
    final verses = passage == null
        ? const <({int verse, String text})>[]
        : await BibleRepository.instance.versesFor(passage);
    final note = await NotesRepository.instance.forDate(_day);

    if (!mounted) return;
    _hasChurch = churchId != null;
    for (var i = 0; i < kNoteFieldCount; i++) {
      _controllers[i].text = note?.answers[i] ?? '';
    }
    setState(() {
      _passage = passage;
      _verses = verses;
      _loading = false;
      _dirty = false;
      _justSaved = false;
    });
  }

  void _onAnyChanged() {
    setState(() {
      _dirty = true;
      _justSaved = false;
    });
    // Автосохранение — тихая подстраховка: срабатывает через секунду после
    // паузы в наборе, чтобы не терять текст. Кнопка при этом остаётся живой.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), _saveNote);
  }

  Future<void> _saveNote() async {
    final answers = _controllers.map((c) => c.text).toList();
    if (mounted) setState(() => _saving = true);
    try {
      await NotesRepository.instance.save(_day, answers);
      ProgressRepository.instance.invalidate(); // обновить значок календаря
      if (mounted) setState(() => _dirty = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить заметку: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Ручное сохранение по кнопке. Работает всегда: если правки есть — пишем,
  /// если автосохранение уже успело — просто подтверждаем. В обоих случаях
  /// даём видимый отклик, чтобы кнопка не ощущалась мёртвой.
  Future<void> _saveNow() async {
    _debounce?.cancel();
    if (_dirty) await _saveNote();
    if (mounted && !_dirty) {
      setState(() => _justSaved = true);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('Заметка сохранена'),
          duration: Duration(seconds: 1),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('QT (Тихое время)'),
        actions: [
          const ProgressCalendarButton(),
          IconButton(
            tooltip: 'Мои заметки',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotesListScreen())),
          ),
          IconButton(
            tooltip: 'Напоминания',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isToday) CatchUpBanner(day: _day),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Text(
                        humanDate(_day),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 12),
                      _buildPassageCard(theme),
                      const SizedBox(height: 24),
                      Text('Мои размышления',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...List.generate(kNoteFieldCount, _buildQuestionTile),
                      const SizedBox(height: 12),
                      _buildSaveButton(),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// «Сохранено» — только отклик на нажатие кнопки. Автосохранение работает
  /// в фоне независимо, но подпись не трогает: иначе она бы сама менялась
  /// через секунду после любой правки, даже без участия пользователя.
  Widget _buildSaveButton() {
    if (_saving) {
      return FilledButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Сохранение…'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      );
    }
    final saved = _justSaved && !_dirty && _hasText;
    // Кнопка активна всегда (кроме момента записи): нажатие сохраняет сразу или
    // подтверждает уже сохранённое. Иначе автосохранение гасило её и она
    // казалась нерабочей.
    return FilledButton.icon(
      onPressed: _saveNow,
      icon: Icon(saved ? Icons.check_circle : Icons.check),
      label: Text(saved ? 'Сохранено' : 'Сохранить'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }

  Widget _buildQuestionTile(int i) {
    final theme = Theme.of(context);
    final controller = _controllers[i];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: ExpansionTile(
        initiallyExpanded: i == 0,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.primary,
          child: Text('${i + 1}',
              style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(kNoteQuestions[i],
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final text = controller.text.trim();
            if (text.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            );
          },
        ),
        children: [
          TextField(
            controller: controller,
            onChanged: (_) => _onAnyChanged(),
            maxLines: null,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'Запишите здесь…',
              border: OutlineInputBorder(),
              filled: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassageCard(ThemeData theme) {
    final passage = _passage;
    if (!_hasChurch) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Церковь не выбрана.'),
              const SizedBox(height: 8),
              Text(
                'Выберите церковь в разделе «Тройка» — тогда появится её график '
                'отрывков и чтения.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }
    if (passage == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('На сегодня отрывок не назначен.'),
              const SizedBox(height: 8),
              Text(
                'Отрывки назначаются на будни. Админ добавляет их в графике '
                'на вкладке «Тройка».',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(passage.reference,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_verses.isEmpty)
              Text(
                'Текста этого отрывка нет в подключённой базе перевода.\n'
                'В образце всего несколько отрывков — подключите полный '
                'Синодальный перевод (см. README).',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              )
            else
              ..._verses.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      children: [
                        TextSpan(
                          text: '${v.verse} ',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: v.text),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
