import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:up_down/data/mock_data.dart';
import 'package:up_down/models/models.dart';

class AppDataSnapshot {
  final List<Team> teams;
  final List<Suggestion> suggestions;

  const AppDataSnapshot({required this.teams, required this.suggestions});
}

class AppDataService {
  AppDataService._();

  static final AppDataService instance = AppDataService._();
  static final Random _random = Random();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _teamsRef =>
      _firestore.collection('teams');

  CollectionReference<Map<String, dynamic>> get _suggestionsRef =>
      _firestore.collection('suggestions');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _linkRequestsRef =>
      _firestore.collection('linkRequests');

  Future<AppDataSnapshot> loadOrSeed({required bool canSeed}) async {
    final teamDocs = await _teamsRef.get();

    if (teamDocs.docs.isEmpty) {
      if (!canSeed) {
        return const AppDataSnapshot(teams: [], suggestions: []);
      }
      final seedTeams = _cloneTeams(mockTeams);
      final seedSuggestions = _cloneSuggestions(mockSuggestions, seedTeams);
      await saveState(seedTeams, seedSuggestions);
      return AppDataSnapshot(teams: seedTeams, suggestions: seedSuggestions);
    }

    final teams = await Future.wait(teamDocs.docs.map(_buildTeamFromDoc));
    final teamsById = {for (final team in teams) team.id: team};

    final suggestionDocs = await _suggestionsRef.get();
    final suggestions = suggestionDocs.docs
        .map((doc) => Suggestion.fromMap(doc.data(), teamsById: teamsById))
        .where((s) => !s.approved && !s.rejected)
        .toList();

    return AppDataSnapshot(teams: teams, suggestions: suggestions);
  }

  Future<void> saveState(List<Team> teams, List<Suggestion> suggestions) async {
    final incomingTeamIds = teams.map((t) => t.id).toSet();
    final existingTeams = await _teamsRef.get();

    for (final doc in existingTeams.docs) {
      if (!incomingTeamIds.contains(doc.id)) {
        await _deleteTeamCascade(doc.reference);
      }
    }

    for (final team in teams) {
      final teamRef = _teamsRef.doc(team.id);
      await teamRef.set(team.toMap(includeMembers: false), SetOptions(merge: true));

      final membersRef = teamRef.collection('members');
      final existingMembers = await membersRef.get();
      final incomingMemberIds = team.members.map((m) => m.id).toSet();

      for (final memberDoc in existingMembers.docs) {
        if (!incomingMemberIds.contains(memberDoc.id)) {
          await memberDoc.reference.delete();
        }
      }

      for (final member in team.members) {
        await membersRef.doc(member.id).set(member.toMap(), SetOptions(merge: true));
      }
    }

    final incomingSuggestionIds = suggestions.map((s) => s.id).toSet();
    final existingSuggestions = await _suggestionsRef.get();

    for (final doc in existingSuggestions.docs) {
      if (!incomingSuggestionIds.contains(doc.id)) {
        await doc.reference.delete();
      }
    }

    for (final suggestion in suggestions) {
      await _suggestionsRef.doc(suggestion.id).set(
            suggestion.toMap(),
            SetOptions(merge: true),
          );
    }
  }

  Future<void> addSuggestion(Suggestion suggestion) async {
    await _suggestionsRef.doc(suggestion.id).set(
          suggestion.toMap(),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteSuggestion(String suggestionId) async {
    await _suggestionsRef.doc(suggestionId).delete();
  }

  Future<void> claimSuggestionApproval(String suggestionId) async {
    final ref = _suggestionsRef.doc(suggestionId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('La sugerencia ya fue procesada.');
      }
      final data = snap.data() ?? <String, dynamic>{};
      final approved = data['approved'] as bool? ?? false;
      final rejected = data['rejected'] as bool? ?? false;
      if (approved || rejected) {
        throw Exception('La sugerencia ya fue procesada.');
      }
      tx.set(
        ref,
        {
          'approved': true,
          'rejected': false,
          'reviewedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> claimSuggestionRejection(String suggestionId) async {
    final ref = _suggestionsRef.doc(suggestionId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('La sugerencia ya fue procesada.');
      }
      final data = snap.data() ?? <String, dynamic>{};
      final approved = data['approved'] as bool? ?? false;
      final rejected = data['rejected'] as bool? ?? false;
      if (approved || rejected) {
        throw Exception('La sugerencia ya fue procesada.');
      }
      tx.set(
        ref,
        {
          'approved': false,
          'rejected': true,
          'reviewedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> approveSuggestionWithEffects({
    required Suggestion suggestion,
    required Member reviewer,
  }) async {
    final suggestionRef = _suggestionsRef.doc(suggestion.id);
    final teamRef = _teamsRef.doc(suggestion.teamId);
    final memberRef = teamRef.collection('members').doc(suggestion.to.id);

    await _firestore.runTransaction((tx) async {
      final suggestionSnap = await tx.get(suggestionRef);
      if (!suggestionSnap.exists) {
        throw Exception('La sugerencia ya fue procesada.');
      }
      final suggestionData = suggestionSnap.data() ?? <String, dynamic>{};
      final approved = suggestionData['approved'] as bool? ?? false;
      final rejected = suggestionData['rejected'] as bool? ?? false;
      if (approved || rejected) {
        throw Exception('La sugerencia ya fue procesada.');
      }

      final action = suggestion.isPositive ? 'positivo' : 'negativo';
      final memberHistoryItem = HistoryItem(
        '$action para ${suggestion.to.displayName} (${suggestion.comment})',
        suggestion.date,
      );
      final teamHistoryItem = HistoryItem(
        'APROBADA: ${memberHistoryItem.description} (por ${reviewer.displayName})',
        DateTime.now(),
      );

      tx.set(
        memberRef,
        {
          if (suggestion.isPositive)
            'positives': FieldValue.increment(1)
          else
            'negatives': FieldValue.increment(1),
          'history': FieldValue.arrayUnion([memberHistoryItem.toMap()]),
        },
        SetOptions(merge: true),
      );
      tx.set(
        teamRef,
        {
          'teamHistory': FieldValue.arrayUnion([teamHistoryItem.toMap()]),
        },
        SetOptions(merge: true),
      );
      tx.set(
        suggestionRef,
        {
          'approved': true,
          'rejected': false,
          'reviewedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> rejectSuggestionWithEffects({
    required Suggestion suggestion,
    required Member reviewer,
  }) async {
    final suggestionRef = _suggestionsRef.doc(suggestion.id);
    final teamRef = _teamsRef.doc(suggestion.teamId);
    final memberRef = teamRef.collection('members').doc(suggestion.to.id);

    await _firestore.runTransaction((tx) async {
      final suggestionSnap = await tx.get(suggestionRef);
      if (!suggestionSnap.exists) {
        throw Exception('La sugerencia ya fue procesada.');
      }
      final suggestionData = suggestionSnap.data() ?? <String, dynamic>{};
      final approved = suggestionData['approved'] as bool? ?? false;
      final rejected = suggestionData['rejected'] as bool? ?? false;
      if (approved || rejected) {
        throw Exception('La sugerencia ya fue procesada.');
      }

      final description =
          'SUGERENCIA RECHAZADA: ${suggestion.from.displayName} sugirio un '
          '${suggestion.isPositive ? 'positivo' : 'negativo'} para '
          '${suggestion.to.displayName}: "${suggestion.comment}"';
      final memberHistoryItem = HistoryItem(description, DateTime.now());
      final teamHistoryItem = HistoryItem(
        '$description (rechazada por ${reviewer.displayName})',
        DateTime.now(),
      );

      tx.set(
        memberRef,
        {
          'history': FieldValue.arrayUnion([memberHistoryItem.toMap()]),
        },
        SetOptions(merge: true),
      );
      tx.set(
        teamRef,
        {
          'teamHistory': FieldValue.arrayUnion([teamHistoryItem.toMap()]),
        },
        SetOptions(merge: true),
      );
      tx.set(
        suggestionRef,
        {
          'approved': false,
          'rejected': true,
          'reviewedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<List<LinkRequest>> getPendingLinkRequests() async {
    final docs = await _linkRequestsRef.get();
    final requests = docs.docs
        .map((doc) => LinkRequest.fromMap(doc.id, doc.data()))
        .where((r) => r.status == LinkRequestStatus.pending)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return requests;
  }

  Future<void> createLinkRequest({
    required String userId,
    required String email,
    required String name,
    required String lastName,
    required Team team,
    String note = '',
  }) async {
    final pendingForUser = await _linkRequestsRef
        .where('userId', isEqualTo: userId)
        .get();
    final hasPending = pendingForUser.docs
        .map((doc) => LinkRequest.fromMap(doc.id, doc.data()))
        .any((request) => request.status == LinkRequestStatus.pending);
    if (hasPending) {
      throw Exception('Ya tienes una solicitud pendiente.');
    }

    final requestRef = _linkRequestsRef.doc(_nextId());
    await requestRef.set({
      'userId': userId,
      'email': email,
      'name': name,
      'lastName': lastName,
      'teamId': team.id,
      'teamName': team.name,
      'note': note.trim(),
      'status': LinkRequestStatus.pending.name,
      'createdAt': DateTime.now().toIso8601String(),
      'reviewedAt': null,
      'reviewedByUid': null,
      'reviewComment': null,
      'memberId': null,
      'memberName': null,
    });

    await _usersRef.doc(userId).set({
      'linkStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> rejectLinkRequest({
    required LinkRequest request,
    required String adminUid,
    String? comment,
  }) async {
    await _linkRequestsRef.doc(request.id).set({
      'status': LinkRequestStatus.rejected.name,
      'reviewedByUid': adminUid,
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewComment': comment?.trim(),
    }, SetOptions(merge: true));

    await _usersRef.doc(request.userId).set({
      'linkStatus': 'unlinked',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> approveLinkRequest({
    required LinkRequest request,
    required String adminUid,
    required Team team,
    required bool createNewMember,
    String? existingMemberId,
    String? newMemberName,
    String? newMemberLastName,
  }) async {
    final teamRef = _teamsRef.doc(team.id);
    final linkRef = _linkRequestsRef.doc(request.id);
    final userRef = _usersRef.doc(request.userId);

    final memberRef = createNewMember
        ? teamRef.collection('members').doc(_nextId())
        : teamRef.collection('members').doc(existingMemberId);

    await _firestore.runTransaction((tx) async {
      final linkSnap = await tx.get(linkRef);
      if (!linkSnap.exists) {
        throw Exception('La solicitud ya no existe.');
      }

      final liveRequest = LinkRequest.fromMap(linkSnap.id, linkSnap.data()!);
      if (liveRequest.status != LinkRequestStatus.pending) {
        throw Exception('La solicitud ya fue gestionada.');
      }

      final memberSnap = await tx.get(memberRef);
      String memberName;
      Map<String, dynamic> memberData;

      if (createNewMember) {
        final resolvedName = (newMemberName ?? '').trim().isEmpty
            ? request.name
            : newMemberName!.trim();
        final resolvedLastName = (newMemberLastName ?? '').trim().isEmpty
            ? request.lastName
            : newMemberLastName!.trim();
        final member = Member(
          id: memberRef.id,
          name: resolvedName,
          lastName: resolvedLastName,
          email: request.email,
          emailLower: request.email.toLowerCase(),
          authUid: request.userId,
          role: UserRole.user,
        );
        memberName = member.displayName;
        memberData = member.toMap();
      } else {
        if (!memberSnap.exists) {
          throw Exception('El integrante seleccionado no existe.');
        }
        final existing = Member.fromMap(memberSnap.data()!);
        if (existing.authUid != null &&
            existing.authUid!.isNotEmpty &&
            existing.authUid != request.userId) {
          throw Exception('El integrante ya esta vinculado a otro usuario.');
        }
        existing.authUid = request.userId;
        existing.email = request.email;
        existing.emailLower = request.email.toLowerCase();
        memberName = existing.displayName;
        memberData = existing.toMap();
      }

      tx.set(memberRef, memberData, SetOptions(merge: true));
      tx.set(userRef, {
        'linkedTeamId': team.id,
        'linkedMemberId': memberRef.id,
        'linkStatus': 'linked',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(linkRef, {
        'status': LinkRequestStatus.approved.name,
        'memberId': memberRef.id,
        'memberName': memberName,
        'reviewedByUid': adminUid,
        'reviewedAt': DateTime.now().toIso8601String(),
        'reviewComment': null,
      }, SetOptions(merge: true));
    });
  }

  Future<List<AppUserRecord>> getUsers() async {
    final docs = await _usersRef.get();
    final users = docs.docs
        .map((doc) => AppUserRecord.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return users;
  }

  Future<void> updateUserRole({
    required String userUid,
    required UserRole role,
    String? linkedTeamIdForGestor,
  }) async {
    final userRef = _usersRef.doc(userUid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw Exception('Usuario no encontrado.');
    }
    final user = AppUserRecord.fromMap(userSnap.id, userSnap.data()!);

    String? resolvedLinkedTeamId = user.linkedTeamId;
    if (role == UserRole.gestor) {
      resolvedLinkedTeamId = (linkedTeamIdForGestor ?? user.linkedTeamId)?.trim();
      if (resolvedLinkedTeamId == null || resolvedLinkedTeamId.isEmpty) {
        throw Exception('Un gestor debe tener equipo asignado.');
      }
    }

    final batch = _firestore.batch();
    batch.set(
      userRef,
      {
        'role': role.name,
        'linkedTeamId': resolvedLinkedTeamId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final teamId = user.linkedTeamId;
    final memberId = user.linkedMemberId;
    if (teamId != null &&
        teamId.isNotEmpty &&
        memberId != null &&
        memberId.isNotEmpty) {
      final memberRef = _teamsRef.doc(teamId).collection('members').doc(memberId);
      batch.set(
        memberRef,
        {'role': role.name},
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<Team> _buildTeamFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final membersDocs = await doc.reference.collection('members').get();
    final members = membersDocs.docs
        .map((m) => Member.fromMap(m.data()))
        .toList();

    final data = doc.data();
    return Team.fromMap({
      ...data,
      'id': doc.id,
      'members': members.map((m) => m.toMap()).toList(),
    });
  }

  Future<void> _deleteTeamCascade(
    DocumentReference<Map<String, dynamic>> teamRef,
  ) async {
    final membersDocs = await teamRef.collection('members').get();
    for (final memberDoc in membersDocs.docs) {
      await memberDoc.reference.delete();
    }
    await teamRef.delete();
  }

  List<Team> _cloneTeams(List<Team> source) {
    return source.map((team) => Team.fromMap(team.toMap())).toList();
  }

  List<Suggestion> _cloneSuggestions(List<Suggestion> source, List<Team> teams) {
    return source
        .map((suggestion) {
          final team = teams
              .where((t) => t.members.any((m) => m.name == suggestion.to.name))
              .firstOrNull;
          if (team == null) {
            return null;
          }

          final fromMember = team.members
              .where((m) => m.name == suggestion.from.name)
              .firstOrNull ??
              suggestion.from;
          final toMember = team.members
              .where((m) => m.name == suggestion.to.name)
              .firstOrNull;

          if (toMember == null) {
            return null;
          }

          return Suggestion(
            from: fromMember,
            to: toMember,
            isPositive: suggestion.isPositive,
            comment: suggestion.comment,
            date: suggestion.date,
            teamId: team.id,
            teamName: team.name,
          );
        })
        .whereType<Suggestion>()
        .toList();
  }

  String _nextId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final r = _random.nextInt(0x7fffffff);
    return '${now}_$r';
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
