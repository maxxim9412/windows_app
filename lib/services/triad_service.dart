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
    };
  }

  /// Создать новую тройку (я — первый участник).
  Future<void> createTriad() async {
    final uid = _uid;
    if (uid == null) throw TriadException('Нужно войти в аккаунт.');
    if (await currentTriadId() != null) {
      throw TriadException('Вы уже состоите в тройке.');
    }
    final profile = await _myProfile();
    final ref = _db.collection('triads').doc();
    await ref.set({
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'memberUids': [uid],
      'members': {uid: profile},
      'inviteCode': _genCode(),
      'joinRequests': {},
      'removalRequests': {},
    });
    reset();
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

    final q = await _db
        .collection('triads')
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();
    if (q.docs.isEmpty) throw TriadException('Тройка с таким кодом не найдена.');

    final ref = q.docs.first.reference;
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
          'members.$joinerUid': {'name': jr['name'], 'email': jr['email']},
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

  static String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // без похожих 0/O/1/I
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
