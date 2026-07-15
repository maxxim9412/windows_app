import 'package:flutter/material.dart';

import '../services/selected_day.dart';
import '../utils/date_helpers.dart';

/// Плашка «вы открыли не сегодняшний день». Без неё легко записать сегодняшнюю
/// мысль во вчерашнюю заметку и не заметить этого.
class CatchUpBanner extends StatelessWidget {
  const CatchUpBanner({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.history,
                size: 18, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Наверстываете: ${humanDate(day)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
            TextButton(
              onPressed: SelectedDay.instance.backToToday,
              child: const Text('К сегодня'),
            ),
          ],
        ),
      ),
    );
  }
}
