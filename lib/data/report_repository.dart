import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/triad.dart';
import '../services/auth_service.dart';

/// Прихожанин церкви — для списка «без тройки».
class ChurchPerson {
  const ChurchPerson({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
  });

  final String uid;
  final String name;
  final String email;
  final String phone;

  String get displayName => name.trim().isEmpty ? 'Без имени' : name;
}

/// Сводка по церкви для админа.
class ChurchReport {
  const ChurchReport({required this.triads, this.members});

  /// Тройки этой церкви.
  final List<Triad> triads;

  /// Прихожане церкви. null — читать профили не разрешено. Это может только
  /// супер-админ: профили остальных закрыты правилами, и запрет распространяется
  /// на подсчёт тоже.
  final List<ChurchPerson>? members;

  int get triadCount => triads.length;
  List<Triad> get fullTriads => triads.where((t) => t.isFull).toList();
  List<Triad> get incompleteTriads => triads.where((t) => !t.isFull).toList();

  /// Людей, состоящих в тройках.
  int get peopleInTriads =>
      triads.fold(0, (total, t) => total + t.memberUids.length);

  int? get totalMembers => members?.length;

  /// Кто ещё не в тройке. null, если прихожане неизвестны.
  List<ChurchPerson>? get withoutTriad {
    final all = members;
    if (all == null) return null;
    final inTriads = {for (final t in triads) ...t.memberUids};
    return all.where((p) => !inTriads.contains(p.uid)).toList();
  }
}

/// Отчёты по церкви.
///
/// Тройки и имена/почты их участников берутся из самих документов троек —
/// профили для этого читать не нужно. Список прихожан (и, значит, «кто без
/// тройки») требует чтения профилей, поэтому доступен только супер-админу.
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

    List<ChurchPerson>? members;
    if (await AuthService.instance.isAdmin()) {
      try {
        final users = await _db
            .collection('users')
            .where('churchId', isEqualTo: churchId)
            .get();
        members = users.docs
            .map((d) => ChurchPerson(
                  uid: d.id,
                  name: (d.data()['name'] as String?) ?? '',
                  email: (d.data()['email'] as String?) ?? '',
                  phone: (d.data()['phone'] as String?) ?? '',
                ))
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
      } catch (_) {
        members = null; // не смогли прочитать — просто не покажем этот раздел
      }
    }
    return ChurchReport(triads: triads, members: members);
  }
}
