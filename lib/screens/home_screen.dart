import 'dart:async';

import 'package:flutter/material.dart';

import '../data/bible_repository.dart';
import '../data/notes_repository.dart';
import '../data/passage_repository.dart';
import '../models/passage.dart';
import '../services/auth_service.dart';
import '../utils/date_helpers.dart';
import '../utils/note_questions.dart';
import 'monthly_schedule_screen.dart';
import 'notes_list_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<TextEditingController> _controllers =
      List.generate(kNoteFieldCount, (_) => TextEditingController());
  final _today = dateOnly(DateTime.now());

  Passage? _passage;
  List<({int verse, String text})> _verses = const [];
  bool _loading = true;
  bool _justSaved = false;
  bool _isAdmin = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final isAdmin = await AuthService.instance.isAdmin();
    final passage = await PassageRepository.instance.forDate(_today);
    final verses = passage == null
        ? const <({int verse, String text})>[]
        : await BibleRepository.instance.versesFor(passage);
    final note = await NotesRepository.instance.forDate(_today);

    if (!mounted) return;
    _isAdmin = isAdmin;
    for (var i = 0; i < kNoteFieldCount; i++) {
      _controllers[i].text = note?.answers[i] ?? '';
    }
    setState(() {
      _passage = passage;
      _verses = verses;
      _loading = false;
    });
  }

  void _onAnyChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _saveNote);
  }

  Future<void> _saveNote() async {
    final answers = _controllers.map((c) => c.text).toList();
    await NotesRepository.instance.save(_today, answers);
  }

  Future<void> _saveNow() async {
    _debounce?.cancel();
    await _saveNote();
    if (!mounted) return;
    setState(() => _justSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('QT (Тихое время)'),
        actions: [
          IconButton(
            tooltip: 'Мои заметки',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotesListScreen())),
          ),
          if (_isAdmin)
            IconButton(
              tooltip: 'График на месяц',
              icon: const Icon(Icons.edit_calendar_outlined),
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MonthlyScheduleScreen()));
                _load();
              },
            ),
          IconButton(
            tooltip: 'Напоминания',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  humanDate(_today),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 12),
                _buildPassageCard(theme),
                const SizedBox(height: 24),
                Text('Мои размышления', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...List.generate(kNoteFieldCount, _buildQuestionTile),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saveNow,
                  icon: Icon(_justSaved ? Icons.check_circle : Icons.check),
                  label: Text(_justSaved ? 'Сохранено' : 'Сохранить'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                ),
                const SizedBox(height: 32),
              ],
            ),
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
    if (passage == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('На сегодня отрывок не назначен.'),
              const SizedBox(height: 8),
              Text(
                'Отрывки назначаются на будни. Добавьте их в «Расписании отрывков» '
                '(значок календаря вверху).',
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
        padding: const EdgeInsets.all(16),
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
