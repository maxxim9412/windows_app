import 'package:flutter/material.dart';

import '../data/notes_repository.dart';
import '../data/passage_repository.dart';
import '../models/note.dart';
import '../utils/date_helpers.dart';
import '../utils/app_dimens.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  late Future<List<Note>> _future;

  @override
  void initState() {
    super.initState();
    _future = NotesRepository.instance.all();
  }

  DateTime _parse(String key) => DateTime.parse(key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Мои заметки')),
      body: FutureBuilder<List<Note>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Не удалось загрузить заметки.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => setState(
                          () => _future = NotesRepository.instance.all()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = snapshot.data ?? const <Note>[];
          if (notes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Text('Пока нет ни одной заметки.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            itemCount: notes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final note = notes[i];
              final day = _parse(note.date);
              return FutureBuilder(
                future: PassageRepository.instance.forDate(day),
                builder: (context, passageSnap) {
                  final ref = passageSnap.data?.reference;
                  return ListTile(
                    title: Text(humanDateShort(day)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ref != null)
                          Text(ref,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary)),
                        const SizedBox(height: 2),
                        Text(note.combined,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
