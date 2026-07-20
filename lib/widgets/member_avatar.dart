import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Аватар участника: фото, если загружено, иначе кружок с первой буквой имени.
///
/// Фото хранится строкой base64 прямо в Firestore (в профиле и в копии
/// участника внутри тройки): Firebase Storage на бесплатном плане новым
/// проектам недоступен, а сжатая аватарка 256×256 — это ~15–25 КБ, документам
/// это не мешает.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    this.photoBase64,
    this.radius = 20,
  });

  final String name;
  final String? photoBase64;
  final double radius;

  /// Кэш декодированных фото. Без него каждый build создавал бы новый массив
  /// байтов → новый MemoryImage → картинка перезагружалась бы и мигала.
  static final Map<String, Uint8List> _decoded = {};

  static Uint8List? _bytesFor(String photo) {
    final cached = _decoded[photo];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(photo);
      // Кэш ограничен: старые записи выкидываем, аватарок на экране немного.
      if (_decoded.length > 32) _decoded.remove(_decoded.keys.first);
      return _decoded[photo] = bytes;
    } catch (_) {
      return null; // битая строка — покажем букву
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = photoBase64;
    if (photo != null && photo.isNotEmpty) {
      final bytes = _bytesFor(photo);
      if (bytes != null) {
        return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes));
      }
    }
    final letter = name.trim().isNotEmpty
        ? name.trim().characters.first.toUpperCase()
        : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary,
      child: Text(letter, style: TextStyle(color: theme.colorScheme.onPrimary)),
    );
  }
}
