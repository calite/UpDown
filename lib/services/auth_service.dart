import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/services/app_data_service.dart';

class CurrentUserProfile {
  final String uid;
  final String email;
  final Member member;
  final String? linkedTeamId;
  final String? linkedMemberId;

  const CurrentUserProfile({
    required this.uid,
    required this.email,
    required this.member,
    required this.linkedTeamId,
    required this.linkedMemberId,
  });

  bool get isLinked =>
      linkedTeamId != null &&
      linkedTeamId!.isNotEmpty &&
      linkedMemberId != null &&
      linkedMemberId!.isNotEmpty;
}

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
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'lastName': lastName,
      'role': UserRole.user.name,
      'email': email,
      'emailLower': email.trim().toLowerCase(),
      'linkedTeamId': null,
      'linkedMemberId': null,
      'linkStatus': 'unlinked',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<CurrentUserProfile> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No hay un usuario autenticado.');
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final data = userDoc.data() ?? <String, dynamic>{};

    final existingEmail = (data['email'] as String?)?.trim();
    final resolvedEmail = (user.email ?? existingEmail ?? '').trim();
    final defaultName = resolvedEmail.isEmpty ? 'Usuario' : resolvedEmail;
    final resolvedName = (data['name'] as String?)?.trim() ?? defaultName;
    final resolvedLastName = (data['lastName'] as String?)?.trim() ?? '';
    final resolvedRole = (data['role'] as String?) ?? UserRole.user.name;
    final resolvedEmailLower = resolvedEmail.toLowerCase();

    final needsBootstrap = !userDoc.exists ||
        (data['role'] as String?) == null ||
        (data['email'] as String?) == null ||
        (data['emailLower'] as String?) == null;
    if (needsBootstrap) {
      await userRef.set({
        'name': resolvedName,
        'lastName': resolvedLastName,
        'role': resolvedRole,
        'email': resolvedEmail,
        'emailLower': resolvedEmailLower,
        'linkStatus': (data['linkStatus'] as String?) ?? 'unlinked',
        'linkedTeamId': data['linkedTeamId'],
        'linkedMemberId': data['linkedMemberId'],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    var linkedTeamId = data['linkedTeamId'] as String?;
    var linkedMemberId = data['linkedMemberId'] as String?;
    final canAttemptAutoLink = resolvedRole != UserRole.admin.name &&
        (linkedTeamId == null || linkedTeamId.isEmpty || linkedMemberId == null || linkedMemberId.isEmpty);
    if (canAttemptAutoLink) {
      final autoLinked = await AppDataService.instance.tryAutoLinkOnLogin(
        userUid: user.uid,
        email: resolvedEmail,
        name: resolvedName,
        lastName: resolvedLastName,
      );
      if (autoLinked != null) {
        linkedTeamId = autoLinked.teamId;
        linkedMemberId = autoLinked.memberId;
      }
    }

    return CurrentUserProfile(
      uid: user.uid,
      email: resolvedEmail,
      linkedTeamId: linkedTeamId,
      linkedMemberId: linkedMemberId,
      member: Member(
        id: user.uid,
        name: resolvedName.isEmpty ? 'Usuario' : resolvedName,
        lastName: resolvedLastName,
        role: resolvedRole == UserRole.admin.name
            ? UserRole.admin
            : resolvedRole == UserRole.gestor.name
                ? UserRole.gestor
                : UserRole.user,
      ),
    );
  }

  Future<Member> getCurrentMemberProfile() async {
    final profile = await getCurrentUserProfile();
    return profile.member;
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
