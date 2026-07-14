import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (аккаунты, тройки, обмен заметками).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Русская локаль для форматирования дат.
  await initializeDateFormatting('ru');

  // Напоминания.
  await NotificationService.instance.init();

  runApp(const BibleReflectionApp());
}
