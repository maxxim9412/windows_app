import 'package:flutter/material.dart';

import '../data/bible_repository.dart';
import '../data/passage_repository.dart';
import '../models/passage.dart';
import '../utils/bible_books.dart';
import '../utils/date_helpers.dart';
import 'admin_import_screen.dart';
import '../utils/app_dimens.dart';

/// Экран администратора: назначение отрывков на дни.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<Passage>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = PassageRepository.instance.all();
  }

  Future<void> _openEditor([Passage? existing]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PassageEditor(existing: existing),
    );
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание отрывков'),
        actions: [
          IconButton(
            tooltip: 'Импорт списком',
            icon: const Icon(Icons.playlist_add),
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const AdminImportScreen()),
              );
              if (changed == true && mounted) setState(_reload);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Отрывок'),
      ),
      body: FutureBuilder<List<Passage>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Text('Отрывков пока нет. Добавьте первый кнопкой ниже.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = items[i];
              return Dismissible(
                key: ValueKey(p.date),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await PassageRepository.instance.deleteByDate(p.date);
                },
                child: ListTile(
                  title: Text(p.reference),
                  subtitle: Text(humanDateShort(DateTime.parse(p.date))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openEditor(p),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PassageEditor extends StatefulWidget {
  final Passage? existing;
  const _PassageEditor({this.existing});

  @override
  State<_PassageEditor> createState() => _PassageEditorState();
}

class _PassageEditorState extends State<_PassageEditor> {
  late DateTime _date;
  late String _bookCode;
  final _chapterCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  String? _preview;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e != null ? DateTime.parse(e.date) : dateOnly(DateTime.now());
    _bookCode = e?.bookCode ?? 'jn';
    if (e != null) {
      _chapterCtrl.text = '${e.chapter}';
      _fromCtrl.text = '${e.verseStart}';
      _toCtrl.text = '${e.verseEnd}';
      _refreshPreview();
    }
  }

  @override
  void dispose() {
    _chapterCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Passage? _buildPassage() {
    final chapter = int.tryParse(_chapterCtrl.text.trim());
    final from = int.tryParse(_fromCtrl.text.trim());
    final to = int.tryParse(_toCtrl.text.trim().isEmpty
        ? _fromCtrl.text.trim()
        : _toCtrl.text.trim());
    if (chapter == null || from == null || to == null || to < from) return null;
    return Passage(
      date: dateKey(_date),
      bookCode: _bookCode,
      chapter: chapter,
      verseStart: from,
      verseEnd: to,
    );
  }

  Future<void> _refreshPreview() async {
    final p = _buildPassage();
    if (p == null) {
      setState(() {
        _preview = null;
        _hasText = false;
      });
      return;
    }
    final verses = await BibleRepository.instance.versesFor(p);
    if (!mounted) return;
    setState(() {
      _hasText = verses.isNotEmpty;
      _preview = verses.isEmpty
          ? null
          : verses.map((v) => '${v.verse} ${v.text}').join('\n');
    });
  }

  Future<void> _save() async {
    final p = _buildPassage();
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проверьте главу и стихи.')),
      );
      return;
    }
    await PassageRepository.instance.upsert(p);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Новый отрывок' : 'Изменить отрывок',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            // Дата
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(humanDateShort(_date)),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = dateOnly(picked));
                },
                child: const Text('Выбрать'),
              ),
            ),
            const SizedBox(height: 8),
            // Книга
            DropdownButtonFormField<String>(
              initialValue: _bookCode,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Книга',
                border: OutlineInputBorder(),
              ),
              items: kBibleBooks
                  .map((b) =>
                      DropdownMenuItem(value: b.code, child: Text(b.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _bookCode = v);
                  _refreshPreview();
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chapterCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Глава', border: OutlineInputBorder()),
                    onChanged: (_) => _refreshPreview(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fromCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Стих с', border: OutlineInputBorder()),
                    onChanged: (_) => _refreshPreview(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _toCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'по', border: OutlineInputBorder()),
                    onChanged: (_) => _refreshPreview(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_preview != null) ...[
              Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('Текст найден в базе',
                      style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(_preview!, style: theme.textTheme.bodyMedium),
              ),
            ] else if (!_hasText &&
                _chapterCtrl.text.isNotEmpty &&
                _fromCtrl.text.isNotEmpty)
              Text(
                'Текста для этого адреса нет в подключённой базе. '
                'Отрывок сохранится, но текст появится только после подключения '
                'полного перевода (см. README).',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
