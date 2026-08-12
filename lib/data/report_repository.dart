import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/triad.dart';
import '../services/auth_service.dart';
import 'church_repository.dart';

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

  /// Кто без телефона. null, если прихожане неизвестны. Церковь у всех в
  /// [members] по определению есть — она и есть фильтр запроса.
  List<ChurchPerson>? get withoutPhone {
    final all = members;
    if (all == null) return null;
    return all.where((p) => p.phone.trim().isEmpty).toList();
  }
}

/// Зарегистрировался, но не завершил профиль: нет церкви и/или телефона.
/// Такие люди не попадают ни в один отчёт по церкви (там выборка идёт по
/// churchId), поэтому нужен отдельный, сквозной по всем церквям список.
///
/// Сюда же попадают те, у кого churchId записан, но указывает на уже
/// удалённую церковь: такой человек невидим ВЕЗДЕ — в выпадашке церквей для
/// отчёта её больше нет, а значит, и запрос по этому churchId никто никогда
/// не сделает. [churchDangling] отличает этот случай от «церковь и не
/// выбирали», чтобы в интерфейсе не путать одно с другим.
class IncompleteProfile {
  const IncompleteProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.churchId,
    required this.churchValid,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? churchId;
  final bool churchValid;
  final DateTime? createdAt;

  String get displayName => name.trim().isEmpty ? 'Без имени' : name;
  bool get missingChurch => !churchValid;
  bool get churchDangling =>
      !churchValid && churchId != null && churchId!.isNotEmpty;
  bool get missingPhone => phone.trim().isEmpty;
}

/// Отчёты по церкви.
///
/// Тройки и имена/почты их участников берутся из самих документов троек —
/// профили для этого читать не нужно. Список прихожан (и, значит, «кто без
/// тройки»/«кто без телефона») требует чтения профилей — по правилам это
/// может супер-админ или админ ЭТОЙ церкви, чужих прихожан админу не видно.
class ReportRepository {
  ReportRepository._();
  static final ReportRepository instance = ReportRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> _canReadMembers(String churchId) async {
    if (await AuthService.instance.isAdmin()) return true;
    final church = await ChurchRepository.instance.byId(churchId);
    return church?.adminUids.contains(AuthService.instance.uid) ?? false;
  }

  Future<ChurchReport> forChurch(String churchId) async {
    final q = await _db
        .collection('triads')
        .where('churchId', isEqualTo: churchId)
        .get();
    final triads = q.docs.map(Triad.fromDoc).toList();

    List<ChurchPerson>? members;
    if (await _canReadMembers(churchId)) {
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

  /// Кто зарегистрировался, но не выбрал церковь (или её потом удалили) и/или
  /// не указал телефон. Доступно только супер-админу — как и остальное чтение
  /// чужих профилей.
  Future<List<IncompleteProfile>> incompleteProfiles() async {
    if (!await AuthService.instance.isAdmin()) return const [];
    final churches = await ChurchRepository.instance.allChurches();
    final validChurchIds = {for (final c in churches) c.id};
    final q = await _db.collection('users').get();
    final people = q.docs
        .map((d) {
          final data = d.data();
          final churchId = data['churchId'] as String?;
          return IncompleteProfile(
            uid: d.id,
            name: (data['name'] as String?) ?? '',
            email: (data['email'] as String?) ?? '',
            phone: (data['phone'] as String?) ?? '',
            churchId: churchId,
            churchValid: churchId != null &&
                churchId.isNotEmpty &&
                validChurchIds.contains(churchId),
            createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          );
        })
        .where((p) => p.missingChurch || p.missingPhone)
        .toList();
    people.sort((a, b) {
      final ac = a.createdAt;
      final bc = b.createdAt;
      if (ac == null && bc == null) return 0;
      if (ac == null) return 1;
      if (bc == null) return -1;
      return bc.compareTo(ac); // сначала недавно зарегистрированные
    });
    return people;
  }
}
