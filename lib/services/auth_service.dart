import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:up_down/models/models.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String lastName,
    required UserRole role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'lastName': lastName,
      'role': role.name,
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Member> getCurrentMemberProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No hay un usuario autenticado.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? <String, dynamic>{};
    final name = (data['name'] as String?)?.trim();
    final lastName = (data['lastName'] as String?)?.trim() ?? '';
    final roleName = data['role'] as String?;

    return Member(
      id: user.uid,
      name: name == null || name.isEmpty ? user.email ?? 'Usuario' : name,
      lastName: lastName,
      role: roleName == UserRole.admin.name ? UserRole.admin : UserRole.user,
    );
  }

  Future<void> updateCurrentUserProfile({
    required String name,
    required String lastName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No hay un usuario autenticado.');
    }

    await _firestore.collection('users').doc(user.uid).set({
      'name': name.trim(),
      'lastName': lastName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() => _auth.signOut();
}
