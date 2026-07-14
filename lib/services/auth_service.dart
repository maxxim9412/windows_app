import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Обёртка над Firebase Auth + профиль пользователя в Firestore.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Регистрация. Создаёт аккаунт, задаёт имя и профиль в Firestore.
  Future<void> register({
    required String email,
    required String password,
    required String name,
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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Профиль пользователя из Firestore (имя, почта).
  Future<Map<String, dynamic>?> profile() async {
    final id = uid;
    if (id == null) return null;
    final doc = await _db.collection('users').doc(id).get();
    return doc.data();
  }

  /// Изменить имя (обновляет и Auth, и профиль в Firestore).
  Future<void> updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await user.reload();
    await _db
        .collection('users')
        .doc(user.uid)
        .set({'name': name.trim()}, SetOptions(merge: true));
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

  /// Является ли текущий пользователь администратором (поле isAdmin в профиле).
  /// Кэшируется до выхода.
  Future<bool> isAdmin() async {
    if (_isAdmin != null) return _isAdmin!;
    final p = await profile();
    _isAdmin = (p?['isAdmin'] as bool?) ?? false;
    return _isAdmin!;
  }

  Future<void> signOut() {
    _isAdmin = null;
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
