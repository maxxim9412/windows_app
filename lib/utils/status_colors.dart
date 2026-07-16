import 'package:flutter/material.dart';

/// Цвета статусов прогресса — «сделано» и «пропущено».
///
/// Они намеренно НЕ зависят от выбранного оформления: смысл должен читаться
/// однозначно при любом основном цвете. Но зависят от светлой/тёмной темы —
/// один фиксированный цвет не может хорошо читаться и на светлом, и на тёмном
/// фоне (проверено по контрасту WCAG на всех палитрах).
Color doneColor(Brightness b) =>
    b == Brightness.light ? const Color(0xFF2E7D32) : const Color(0xFF7FCB82);

Color missedColor(Brightness b) =>
    b == Brightness.light ? const Color(0xFFBF4A00) : const Color(0xFFFFA726);
