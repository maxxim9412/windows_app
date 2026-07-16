import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/church_repository.dart';

/// Обёртка над Firebase Auth + профиль пользователя в Firestore.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Регистрация. Создаёт аккаунт, задаёт имя, церковь и профиль в Firestore.
  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? churchId,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(name.trim());
    await user.reload();
    await _db.collection('users').doc(user.uid).set({
      'email': email.trim().toLowerCase(),
      'name': name.trim(),
      'phone': phone.trim(),
      'churchId': churchId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _churchId = churchId;
    _churchFetched = true;
  }

  /// Профиль пользователя из Firestore (имя, почта).
  Future<Map<String, dynamic>?> profile() async {
    final id = uid;
    if (id == null) return null;
    final doc = await _db.collection('users').doc(id).get();
    return doc.data();
  }

  /// Изменить имя и телефон (обновляет и Auth, и профиль в Firestore).
  ///
  /// Копию этих данных держит ещё и документ тройки — её обновляет
  /// TriadService.syncMyProfileToTriad, который вызывается следом. Иначе тройка
  /// продолжила бы показывать старое имя и телефон.
  Future<void> updateProfile({String? name, String? phone}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final data = <String, dynamic>{};
    if (name != null) {
      await user.updateDisplayName(name.trim());
      await user.reload();
      data['name'] = name.trim();
    }
    if (phone != null) data['phone'] = phone.trim();
    if (data.isEmpty) return;
    await _db
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Отправить письмо для сброса пароля.
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  bool? _isAdmin;

  /// Супер-админ (поле isAdmin в профиле): управляет церквями и их админами.
  Future<bool> isAdmin() async {
    if (_isAdmin != null) return _isAdmin!;
    final p = await profile();
    _isAdmin = (p?['isAdmin'] as bool?) ?? false;
    return _isAdmin!;
  }

  // --- Церковь пользователя ----------------------------------------------
  String? _churchId;
  bool _churchFetched = false;

  Future<String?> currentChurchId() async {
    if (_churchFetched) return _churchId;
    final p = await profile();
    _churchId = p?['churchId'] as String?;
    _churchFetched = true;
    return _churchId;
  }

  /// Сменить свою церковь.
  Future<void> setChurch(String? churchId) async {
    final id = uid;
    if (id == null) return;
    await _db
        .collection('users')
        .doc(id)
        .set({'churchId': churchId}, SetOptions(merge: true));
    _churchId = churchId;
    _churchFetched = true;
  }

  /// Является ли текущий пользователь админом СВОЕЙ церкви (ведёт её график).
  Future<bool> isChurchAdmin() async {
    final cid = await currentChurchId();
    if (cid == null) return false;
    final church = await ChurchRepository.instance.byId(cid);
    return church?.adminUids.contains(uid) ?? false;
  }

  Future<void> signOut() {
    _isAdmin = null;
    _churchId = null;
    _churchFetched = false;
    return _auth.signOut();
  }

  /// Человекочитаемое сообщение об ошибке авторизации.
  static String messageFor(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'Некорректный адрес почты.';
        case 'email-already-in-use':
          return 'Этот адрес уже зарегистрирован.';
        case 'weak-password':
          return 'Слишком простой пароль (минимум 6 символов).';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Неверная почта или пароль.';
        case 'network-request-failed':
          return 'Нет соединения с интернетом.';
        default:
          return 'Ошибка входа: ${e.code}';
      }
    }
    return 'Что-то пошло не так. Попробуйте ещё раз.';
  }
}
