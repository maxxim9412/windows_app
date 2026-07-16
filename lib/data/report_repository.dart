import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/triad.dart';
import '../services/auth_service.dart';

/// Сводка по церкви для админа.
class ChurchReport {
  const ChurchReport({
    required this.triads,
    required this.totalMembers,
  });

  /// Тройки этой церкви.
  final List<Triad> triads;

  /// Всего людей в церкви. null — считать не разрешено (это может только
  /// супер-админ: профили остальных закрыты правилами).
  final int? totalMembers;

  int get triadCount => triads.length;
  List<Triad> get fullTriads => triads.where((t) => t.isFull).toList();
  List<Triad> get incompleteTriads => triads.where((t) => !t.isFull).toList();

  /// Людей, состоящих в тройках.
  int get peopleInTriads =>
      triads.fold(0, (total, t) => total + t.memberUids.length);

  /// Людей без тройки. null, если общее число людей неизвестно.
  int? get peopleWithoutTriad {
    final total = totalMembers;
    return total == null ? null : total - peopleInTriads;
  }
}

/// Отчёты по церкви. Считает по тройкам: имена участников лежат в самом
/// документе тройки, поэтому профили читать не нужно — а их правила и не дают
/// читать никому, кроме владельца и супер-админа.
class ReportRepository {
  ReportRepository._();
  static final ReportRepository instance = ReportRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<ChurchReport> forChurch(String churchId) async {
    final q = await _db
        .collection('triads')
        .where('churchId', isEqualTo: churchId)
        .get();
    final triads = q.docs.map(Triad.fromDoc).toList();

    // Общее число людей — только супер-админу: у остальных нет прав на чтение
    // чужих профилей, а запрет распространяется и на подсчёт.
    int? total;
    if (await AuthService.instance.isAdmin()) {
      try {
        final agg = await _db
            .collection('users')
            .where('churchId', isEqualTo: churchId)
            .count()
            .get();
        total = agg.count;
      } catch (_) {
        total = null; // не смогли посчитать — просто не покажем строку
      }
    }
    return ChurchReport(triads: triads, totalMembers: total);
  }
}
