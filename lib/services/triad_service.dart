import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/triad.dart';
import 'auth_service.dart';

/// Результат попытки вступления по коду.
enum JoinOutcome { joined, requested }

class TriadException implements Exception {
  final String message;
  TriadException(this.message);
  @override
  String toString() => message;
}

/// Управление «тройками»: создание, приглашение по коду, согласие на приём
/// 3-го участника и на удаление, обмен участниками.
class TriadService {
  TriadService._();
  static final TriadService instance = TriadService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String inviteBaseUrl = 'https://bible-reflection.app/join?code=';

  String? get _uid => AuthService.instance.uid;

  // --- Кэш «моей» тройки (для привязки заметок) ---------------------------
  String? _cachedTriadId;
  bool _fetched = false;

  Future<String?> currentTriadId() async {
    if (_fetched) return _cachedTriadId;
    final uid = _uid;
    if (uid == null) return null;
    final q = await _db
        .collection('triads')
        .where('memberUids', arrayContains: uid)
        .limit(1)
        .get();
    _cachedTriadId = q.docs.isEmpty ? null : q.docs.first.id;
    _fetched = true;
    return _cachedTriadId;
  }

  void reset() {
    _fetched = false;
    _cachedTriadId = null;
  }

  // --- Потоки -------------------------------------------------------------

  /// Тройка, в которой я состою (или null).
  Stream<Triad?> myTriadStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _db
        .collection('triads')
        .where('memberUids', arrayContains: uid)
        .limit(1)
        .snapshots()
        .map((q) => q.docs.isEmpty ? null : Triad.fromDoc(q.docs.first));
  }

  /// id тройки, куда я подал заявку 3-м участником (или null).
  Stream<String?> pendingTriadIdStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map(
        (d) => (d.data()?['pendingTriadId'] as String?));
  }

  Stream<Triad?> triadStream(String triadId) => _db
      .collection('triads')
      .doc(triadId)
      .snapshots()
      .map((d) => d.exists ? Triad.fromDoc(d) : null);

  // --- Совместная встреча: синхронно показываемая заметка -----------------

  /// Поток текущей показываемой заметки: {ownerUid, date, by}.
  Stream<Map<String, dynamic>?> sharedSessionStream(String triadId) => _db
      .collection('triads')
      .doc(triadId)
      .collection('shared')
      .doc('current')
      .snapshots()
      .map((d) => d.exists ? d.data() : null);

  /// Показать всем заметку участника [ownerUid] за день [date] (yyyy-MM-dd).
  Future<void> presentNote(
      String triadId, String ownerUid, String date) async {
    await _db
        .collection('triads')
        .doc(triadId)
        .collection('shared')
        .doc('current')
        .set({
      'ownerUid': ownerUid,
      'date': date,
      'by': _uid,
      'at': FieldValue.serverTimestamp(),
    });
  }

  // --- Операции -----------------------------------------------------------

  Future<Map<String, dynamic>> _myProfile() async {
    final p = await AuthService.instance.profile();
    return {
      'name': (p?['name'] as String?) ?? '',
      'email': (p?['email'] as String?) ??
          AuthService.instance.currentUser?.email ??
          '',
      'phone': (p?['phone'] as String?) ?? '',
    };
  }

  /// Обновить свою копию в документе тройки после правки профиля.
  ///
  /// Тройка хранит имя, почту и телефон копией: правила не дают участникам
  /// читать профили друг друга. Без этого вызова тройка навсегда осталась бы со
  /// старыми данными — до этой правки так и было со сменой имени.
  Future<void> syncMyProfileToTriad() async {
    try {
      final uid = _uid;
      if (uid == null) return;
      final triadId = await currentTriadId();
      if (triadId == null) return;
      final profile = await _myProfile();
      await _db
          .collection('triads')
          .doc(triadId)
          .update({'members.$uid': profile});
    } catch (_) {
      // Не критично: копия обновится при следующей правке профиля.
    }
  }

  /// Создать новую тройку (я — первый участник). Церковь обязательна: тройка
  /// читает график своей церкви, значит у неё должна быть церковь.
  Future<void> createTriad() async {
    final uid = _uid;
    if (uid == null) throw TriadException('Нужно войти в аккаунт.');
    if (await currentTriadId() != null) {
      throw TriadException('Вы уже состоите в тройке.');
    }
    final churchId = await AuthService.instance.currentChurchId();
    if (churchId == null) {
      throw TriadException(
          'Сначала выберите церковь — тройка читает график своей церкви.');
    }
    final profile = await _myProfile();
    final ref = _db.collection('triads').doc();
    final code = _genCode();
    // Тройку и запись в индексе кодов пишем одной пачкой: тройка без своего
    // кода в индексе не находится по приглашению.
    final batch = _db.batch();
    batch.set(ref, {
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'memberUids': [uid],
      'members': {uid: profile},
      'inviteCode': code,
      'joinRequests': {},
      'removalRequests': {},
      'churchId': churchId,
    });
    batch.set(_codeRef(code), {'triadId': ref.id});
    await batch.commit();
    reset();
  }

  /// Индекс «код приглашения → id тройки» (`inviteCodes/{КОД}`).
  ///
  /// Нужен, чтобы вступление по коду не требовало листать сами тройки. Раньше
  /// поиск шёл запросом `where('inviteCode', ...)`, а правила Firestore не
  /// умеют ограничивать запрос по фильтру — приходилось разрешать читать список
  /// троек любому вошедшему. А в документе тройки лежат имена и почты всех
  /// участников, то есть их можно было выгрузить пачкой. В индексе личных
  /// данных нет, поэтому его читать безопасно.
  DocumentReference<Map<String, dynamic>> _codeRef(String code) =>
      _db.collection('inviteCodes').doc(code);

  /// Дописать индекс для тройки, созданной до его появления. Иначе её код
  /// перестал бы находиться. Тихо ничего не делает, если всё уже на месте.
  Future<void> ensureInviteCodeIndexed() async {
    try {
      final uid = _uid;
      if (uid == null) return;
      final q = await _db
          .collection('triads')
          .where('memberUids', arrayContains: uid)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return;
      final code = q.docs.first.data()['inviteCode'] as String?;
      if (code == null || code.isEmpty) return;
      final indexed = await _codeRef(code).get();
      if (!indexed.exists) {
        await _codeRef(code).set({'triadId': q.docs.first.id});
      }
    } catch (_) {
      // Не критично: попробуем при следующем запуске.
    }
  }

  /// Достать код из введённой строки (кода или ссылки).
  static String extractCode(String input) {
    final s = input.trim();
    final idx = s.indexOf('code=');
    final raw = idx >= 0 ? s.substring(idx + 5) : s;
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Вступить по коду/ссылке. 2-й участник входит сразу, 3-й — через заявку.
  Future<JoinOutcome> joinByCode(String codeOrLink) async {
    final uid = _uid;
    if (uid == null) throw TriadException('Нужно войти в аккаунт.');
    if (await currentTriadId() != null) {
      throw TriadException('Вы уже состоите в тройке.');
    }
    final code = extractCode(codeOrLink);
    if (code.isEmpty) throw TriadException('Введите код приглашения.');

    final myChurchId = await AuthService.instance.currentChurchId();
    if (myChurchId == null) {
      throw TriadException(
          'Сначала выберите церковь — тройка читает график своей церкви.');
    }

    // Ищем через индекс кодов, а не запросом по тройкам: листать тройки больше
    // нельзя (в них имена и почты участников), см. [_codeRef].
    final indexed = await _codeRef(code).get();
    final triadId = indexed.data()?['triadId'] as String?;
    if (triadId == null) {
      throw TriadException('Тройка с таким кодом не найдена.');
    }
    final ref = _db.collection('triads').doc(triadId);
    final snap = await ref.get();
    if (!snap.exists) {
      // Индекс пережил свою тройку — например, все из неё вышли.
      throw TriadException('Тройка с таким кодом не найдена.');
    }

    // Церковь берём с самой тройки: чужой профиль читать нельзя (правила), да и
    // сверять надо с тройкой, а не с тем, кто прислал код.
    final triadChurchId = snap.data()!['churchId'] as String?;
    if (triadChurchId != null && triadChurchId != myChurchId) {
      throw TriadException(
          'Эта тройка из другой церкви. Участники тройки читают один и тот же '
          'график, поэтому вступить можно только в тройку своей церкви.');
    }

    final profile = await _myProfile();

    final outcome = await _db.runTransaction<JoinOutcome>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data()!;
      final members = List<String>.from(data['memberUids'] as List? ?? const []);
      if (members.contains(uid)) return JoinOutcome.joined;
      if (members.length >= 3) throw TriadException('В тройке уже 3 человека.');

      if (members.length == 1) {
        // 2-й участник — сразу.
        tx.update(ref, {
          'memberUids': FieldValue.arrayUnion([uid]),
          'members.$uid': profile,
        });
        return JoinOutcome.joined;
      } else {
        // 3-й участник — заявка на одобрение.
        tx.update(ref, {
          'joinRequests.$uid': {
            'name': profile['name'],
            'email': profile['email'],
            'phone': profile['phone'],
            'approvals': <String>[],
          },
        });
        return JoinOutcome.requested;
      }
    });

    if (outcome == JoinOutcome.joined) {
      reset();
    } else {
      await _db
          .collection('users')
          .doc(uid)
          .set({'pendingTriadId': ref.id}, SetOptions(merge: true));
    }
    return outcome;
  }

  /// Отменить свою заявку на вступление.
  Future<void> cancelJoinRequest(String triadId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('triads').doc(triadId).update({
      'joinRequests.$uid': FieldValue.delete(),
    });
    await _clearPending();
  }

  Future<void> _clearPending() async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .set({'pendingTriadId': FieldValue.delete()}, SetOptions(merge: true));
  }

  /// Одобрить заявку 3-го участника. Когда одобрили все существующие — принят.
  Future<void> approveJoin(String triadId, String joinerUid) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _db.collection('triads').doc(triadId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data()!;
      final members = List<String>.from(data['memberUids'] as List? ?? const []);
      if (!members.contains(uid)) throw TriadException('Вы не участник тройки.');
      final requests = Map<String, dynamic>.from(data['joinRequests'] ?? {});
      final jr = requests[joinerUid] as Map<String, dynamic>?;
      if (jr == null) return;
      if (members.length >= 3) throw TriadException('В тройке уже 3 человека.');

      final approvals = List<String>.from(jr['approvals'] as List? ?? const []);
      if (!approvals.contains(uid)) approvals.add(uid);

      // Нужно одобрение всех текущих участников.
      final allApproved = members.every(approvals.contains);
      if (allApproved) {
        tx.update(ref, {
          'memberUids': FieldValue.arrayUnion([joinerUid]),
          'members.$joinerUid': {
            'name': jr['name'],
            'email': jr['email'],
            'phone': jr['phone'] ?? '',
          },
          'joinRequests.$joinerUid': FieldValue.delete(),
        });
      } else {
        tx.update(ref, {'joinRequests.$joinerUid.approvals': approvals});
      }
    });
  }

  Future<void> declineJoin(String triadId, String joinerUid) async {
    await _db.collection('triads').doc(triadId).update({
      'joinRequests.$joinerUid': FieldValue.delete(),
    });
  }

  /// Запросить удаление участника (только в полной тройке из 3).
  Future<void> requestRemoval(String triadId, TriadMember target) async {
    final uid = _uid;
    if (uid == null) return;
    if (target.uid == uid) throw TriadException('Себя удалять не нужно — выйдите.');
    await _db.collection('triads').doc(triadId).update({
      'removalRequests.${target.uid}': {
        'by': uid,
        'targetName': target.name,
        'approvals': [uid],
      },
    });
  }

  /// Одобрить удаление. Когда согласны все, кроме удаляемого — участник убран.
  Future<void> approveRemoval(String triadId, String targetUid) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _db.collection('triads').doc(triadId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data()!;
      final members = List<String>.from(data['memberUids'] as List? ?? const []);
      final removals = Map<String, dynamic>.from(data['removalRequests'] ?? {});
      final rr = removals[targetUid] as Map<String, dynamic>?;
      if (rr == null) return;

      final approvals = List<String>.from(rr['approvals'] as List? ?? const []);
      if (!approvals.contains(uid)) approvals.add(uid);

      // Согласны должны все участники, кроме удаляемого.
      final others = members.where((m) => m != targetUid);
      final allAgree = others.every(approvals.contains);
      if (allAgree) {
        tx.update(ref, {
          'memberUids': FieldValue.arrayRemove([targetUid]),
          'members.$targetUid': FieldValue.delete(),
          'removalRequests.$targetUid': FieldValue.delete(),
        });
      } else {
        tx.update(ref, {'removalRequests.$targetUid.approvals': approvals});
      }
    });
  }

  Future<void> cancelRemoval(String triadId, String targetUid) async {
    await _db.collection('triads').doc(triadId).update({
      'removalRequests.$targetUid': FieldValue.delete(),
    });
  }

  /// Выйти из тройки самому. Пустая тройка удаляется.
  Future<void> leave(String triadId) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _db.collection('triads').doc(triadId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final members = List<String>.from(data['memberUids'] as List? ?? const []);
      members.remove(uid);
      if (members.isEmpty) {
        tx.delete(ref);
        // Убираем и код из индекса, иначе он остался бы указывать в пустоту.
        final code = data['inviteCode'] as String?;
        if (code != null && code.isNotEmpty) tx.delete(_codeRef(code));
      } else {
        tx.update(ref, {
          'memberUids': FieldValue.arrayRemove([uid]),
          'members.$uid': FieldValue.delete(),
          // Запросы на удаление актуальны только для тройки из 3 — сбрасываем.
          'removalRequests': {},
        });
      }
    });
    reset();
  }

  // --- Расписание звонков (изменения — по согласию участников) ------------

  Future<void> proposeSchedule(
      String triadId, List<int> days, int hour, int minute) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('triads').doc(triadId).update({
      'scheduleProposal': {
        'days': days,
        'hour': hour,
        'minute': minute,
        'by': uid,
        'approvals': [uid],
      },
    });
  }

  Future<void> approveSchedule(String triadId) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _db.collection('triads').doc(triadId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data()!;
      final members = List<String>.from(data['memberUids'] as List? ?? const []);
      final p = data['scheduleProposal'] as Map<String, dynamic>?;
      if (p == null) return;
      final approvals = List<String>.from(p['approvals'] as List? ?? const []);
      if (!approvals.contains(uid)) approvals.add(uid);

      if (members.every(approvals.contains)) {
        tx.update(ref, {
          'callSchedule': {
            'days': p['days'],
            'hour': p['hour'],
            'minute': p['minute'],
          },
          'scheduleProposal': FieldValue.delete(),
        });
      } else {
        tx.update(ref, {'scheduleProposal.approvals': approvals});
      }
    });
  }

  Future<void> cancelScheduleProposal(String triadId) async {
    await _db.collection('triads').doc(triadId).update({
      'scheduleProposal': FieldValue.delete(),
    });
  }

  // --- Состояние активного звонка -----------------------------------------

  DocumentReference<Map<String, dynamic>> _callRef(String triadId) =>
      _db.collection('triads').doc(triadId).collection('shared').doc('call');

  Stream<Map<String, dynamic>?> callStateStream(String triadId) =>
      _callRef(triadId).snapshots().map((d) => d.exists ? d.data() : null);

  /// Отметить, что звонок идёт (я вошёл). Если ещё не активен — я «начинающий».
  Future<void> markCallActive(String triadId) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _callRef(triadId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final active = (snap.data()?['active'] as bool?) ?? false;
      if (!active) {
        tx.set(ref, {
          'active': true,
          'startedBy': uid,
          'startedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> endCall(String triadId) async {
    await _callRef(triadId).set({'active': false}, SetOptions(merge: true));
  }

  /// Идёт ли сейчас «время звонка» по расписанию (для звука входящего).
  static bool isWithinSchedule(CallSchedule? s, DateTime now) {
    if (s == null || s.days.isEmpty) return false;
    if (!s.days.contains(now.weekday)) return false;
    final scheduled =
        DateTime(now.year, now.month, now.day, s.hour, s.minute);
    final diffMin = now.difference(scheduled).inMinutes;
    return diffMin >= -5 && diffMin <= 60;
  }

  static String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // без похожих 0/O/1/I
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
