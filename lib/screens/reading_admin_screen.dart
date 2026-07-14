import 'package:flutter/material.dart';

import '../data/reading_repository.dart';
import '../models/reading.dart';
import '../utils/bible_books.dart';
import '../utils/date_helpers.dart';
import 'reading_import_screen.dart';

/// Экран администратора для плана ежедневного чтения.
class ReadingAdminScreen extends StatefulWidget {
  const ReadingAdminScreen({super.key});

  @override
  State<ReadingAdminScreen> createState() => _ReadingAdminScreenState();
}

class _ReadingAdminScreenState extends State<ReadingAdminScreen> {
  late Future<List<Reading>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ReadingRepository.instance.all();
  }

  Future<void> _openEditor() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReadingEditor(),
    );
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('План чтения'),
        actions: [
          IconButton(
            tooltip: 'Импорт списком',
            icon: const Icon(Icons.playlist_add),
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const ReadingImportScreen()),
              );
              if (changed == true && mounted) setState(_reload);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: const Text('Чтение'),
      ),
      body: FutureBuilder<List<Reading>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                    'План чтения пуст. Добавьте главы кнопкой ниже или импортом.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = items[i];
              return Dismissible(
                key: ValueKey('${r.date}#${r.orderIndex}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await ReadingRepository.instance
                      .removePortion(r.date, r.orderIndex);
                },
                child: ListTile(
                  title: Text(r.reference),
                  subtitle: Text(humanDateShort(DateTime.parse(r.date))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReadingEditor extends StatefulWidget {
  const _ReadingEditor();

  @override
  State<_ReadingEditor> createState() => _ReadingEditorState();
}

class _ReadingEditorState extends State<_ReadingEditor> {
  DateTime _date = dateOnly(DateTime.now());
  String _bookCode = 'gen';
  final _fromCtrl = TextEditingController(text: '1');
  final _toCtrl = TextEditingController();

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cs = int.tryParse(_fromCtrl.text.trim());
    final ce = int.tryParse(
        _toCtrl.text.trim().isEmpty ? _fromCtrl.text.trim() : _toCtrl.text.trim());
    if (cs == null || ce == null || ce < cs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проверьте номера глав.')),
      );
      return;
    }
    await ReadingRepository.instance.addPortion(
      dateKey(_date),
      Reading(
        date: dateKey(_date),
        bookCode: _bookCode,
        chapterStart: cs,
        chapterEnd: ce,
      ),
    );
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
            Text('Чтение на день', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
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
            DropdownButtonFormField<String>(
              initialValue: _bookCode,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Книга', border: OutlineInputBorder()),
              items: kBibleBooks
                  .map((b) =>
                      DropdownMenuItem(value: b.code, child: Text(b.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _bookCode = v);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fromCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Глава с', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _toCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'по (необязательно)',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}
