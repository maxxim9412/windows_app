import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/church.dart';

/// Управление церквями (супер-админ) + справочник для выбора при регистрации.
class ChurchRepository {
  ChurchRepository._();
  static final ChurchRepository instance = ChurchRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('churches');

  Stream<List<Church>> streamChurches() => _col
      .orderBy('name')
      .snapshots()
      .map((q) => q.docs.map(Church.fromDoc).toList());

  Future<List<Church>> allChurches() async {
    final q = await _col.orderBy('name').get();
    return q.docs.map(Church.fromDoc).toList();
  }

  Future<Church?> byId(String id) async {
    final doc = await _col.doc(id).get();
    return doc.exists ? Church.fromDoc(doc) : null;
  }

  Future<void> create(String name) async {
    await _col.add({
      'name': name.trim(),
      'adminUids': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> addAdmin(String churchId, String uid) async {
    await _col.doc(churchId).update({
      'adminUids': FieldValue.arrayUnion([uid])
    });
  }

  Future<void> removeAdmin(String churchId, String uid) async {
    await _col.doc(churchId).update({
      'adminUids': FieldValue.arrayRemove([uid])
    });
  }

  /// Найти uid и имя пользователя по email (для назначения админом).
  Future<({String uid, String name})?> userByEmail(String email) async {
    final q = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    return (uid: d.id, name: (d.data()['name'] as String?) ?? '');
  }

  /// Имена по списку uid (для показа админов церкви).
  Future<Map<String, String>> namesFor(List<String> uids) async {
    final result = <String, String>{};
    for (final uid in uids) {
      final doc = await _db.collection('users').doc(uid).get();
      result[uid] = (doc.data()?['name'] as String?) ?? uid;
    }
    return result;
  }
}
