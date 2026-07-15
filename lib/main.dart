import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // В вебе initializeApp иногда не завершает Future — ограничиваем таймаутом,
  // чтобы интерфейс запустился (Firebase при этом остаётся инициализированным).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 6));
  } catch (e) {
    debugPrint('[main] Firebase init: $e');
  }

  try {
    await initializeDateFormatting('ru');
  } catch (e) {
    debugPrint('[main] intl: $e');
  }

  await NotificationService.instance.init();

  runApp(const BibleReflectionApp());
}