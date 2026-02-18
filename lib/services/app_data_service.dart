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

  Future<({String teamId, String memberId})?> tryAutoLinkOnLogin({
    required String userUid,
    required String email,
    required String name,
    required String lastName,
  }) async {
    final emailLower = email.trim().toLowerCase();
    if (emailLower.isEmpty) {
      return null;
    }

    final userSnap = await _usersRef.doc(userUid).get();
    final userData = userSnap.data() ?? const <String, dynamic>{};
    final alreadyLinked =
        (userData['linkedTeamId'] as String?)?.trim().isNotEmpty == true &&
        (userData['linkedMemberId'] as String?)?.trim().isNotEmpty == true;
    if (alreadyLinked) {
      return (
        teamId: (userData['linkedTeamId'] as String).trim(),
        memberId: (userData['linkedMemberId'] as String).trim(),
      );
    }

    final autoApproveTeams = await _teamsRef
        .where('settings.autoApproveJoinRequests', isEqualTo: true)
        .get();
    final matches = <({String teamId, DocumentReference<Map<String, dynamic>> memberRef})>[];

    for (final teamDoc in autoApproveTeams.docs) {
      final membersSnap = await teamDoc.reference.collection('members').get();
      for (final memberDoc in membersSnap.docs) {
        final data = memberDoc.data();
        final memberEmailLower =
            ((data['emailLower'] as String?)?.trim().isNotEmpty ?? false)
                ? (data['emailLower'] as String).trim()
                : ((data['email'] as String?)?.trim().toLowerCase() ?? '');
        final authUid = (data['authUid'] as String?)?.trim() ?? '';
        final canClaim = authUid.isEmpty || authUid == userUid;
        if (memberEmailLower == emailLower && canClaim) {
          matches.add((teamId: teamDoc.id, memberRef: memberDoc.reference));
        }
      }
    }

    if (matches.isEmpty && autoApproveTeams.docs.length == 1) {
      final onlyTeam = autoApproveTeams.docs.first;
      final memberRef = onlyTeam.reference.collection('members').doc(userUid);
      final batch = _firestore.batch();
      _appendUnlinkPreviousMemberToBatch(
        batch: batch,
        currentLinkedTeamId: (userData['linkedTeamId'] as String?)?.trim(),
        currentLinkedMemberId: (userData['linkedMemberId'] as String?)?.trim(),
        nextLinkedTeamId: onlyTeam.id,
        nextLinkedMemberId: memberRef.id,
      );
      batch.set(
        memberRef,
        {
          'id': memberRef.id,
          'name': name.trim().isEmpty ? email.trim() : name.trim(),
          'lastName': lastName.trim(),
          'email': email.trim(),
          'emailLower': emailLower,
          'authUid': userUid,
          'role': UserRole.user.name,
        },
        SetOptions(merge: true),
      );
      batch.set(
        _usersRef.doc(userUid),
        {
          'linkedTeamId': onlyTeam.id,
          'linkedMemberId': memberRef.id,
          'linkStatus': 'linked',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await _appendClearDuplicateUserLinksToBatch(
        batch: batch,
        userUid: userUid,
        keepTeamId: onlyTeam.id,
        keepMemberId: memberRef.id,
      );
      await batch.commit();
      return (teamId: onlyTeam.id, memberId: memberRef.id);
    }

    if (matches.length != 1) {
      return null;
    }

    final target = matches.first;
    final batch = _firestore.batch();
    _appendUnlinkPreviousMemberToBatch(
      batch: batch,
      currentLinkedTeamId: (userData['linkedTeamId'] as String?)?.trim(),
      currentLinkedMemberId: (userData['linkedMemberId'] as String?)?.trim(),
      nextLinkedTeamId: target.teamId,
      nextLinkedMemberId: target.memberRef.id,
    );
    batch.set(
      target.memberRef,
      {
        'authUid': userUid,
        'email': email.trim(),
        'emailLower': emailLower,
        'name': name.trim().isEmpty ? email.trim() : name.trim(),
        'lastName': lastName.trim(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _usersRef.doc(userUid),
      {
        'linkedTeamId': target.teamId,
        'linkedMemberId': target.memberRef.id,
        'linkStatus': 'linked',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _appendClearDuplicateUserLinksToBatch(
      batch: batch,
      userUid: userUid,
      keepTeamId: target.teamId,
      keepMemberId: target.memberRef.id,
    );
    await batch.commit();
    return (teamId: target.teamId, memberId: target.memberRef.id);
  }

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

  Future<bool> createLinkRequest({
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

    final userSnap = await _usersRef.doc(userId).get();
    final userData = userSnap.data() ?? <String, dynamic>{};
    final currentLinkedTeamId = (userData['linkedTeamId'] as String?)?.trim();
    final currentLinkedMemberId = (userData['linkedMemberId'] as String?)?.trim();

    final teamSnap = await _teamsRef.doc(team.id).get();
    final teamData = teamSnap.data() ?? <String, dynamic>{};
    final settings = TeamSettings.fromMap(
      teamData['settings'] is Map
          ? Map<String, dynamic>.from(teamData['settings'] as Map)
          : const {},
    );

    final emailLower = email.toLowerCase().trim();
    if (settings.autoApproveJoinRequests) {
      final membersSnap = await _teamsRef.doc(team.id).collection('members').get();

      final matches = membersSnap.docs.where((doc) {
        final data = doc.data();
        final candidateEmail = ((data['emailLower'] as String?)?.trim().isNotEmpty ?? false)
            ? (data['emailLower'] as String).trim()
            : ((data['email'] as String?)?.trim().toLowerCase() ?? '');
        return candidateEmail == emailLower;
      }).toList();
      DocumentReference<Map<String, dynamic>> memberRef;
      String memberName;

      if (matches.length > 1) {
        // Ambiguo: requiere revision manual.
      } else if (matches.length == 1) {
        final existing = Member.fromMap(matches.first.data());
        final authUid = (matches.first.data()['authUid'] as String?)?.trim();
        if ((authUid?.isNotEmpty ?? false) && authUid != userId) {
          // Integrante ya vinculado a otro usuario: requiere revision manual.
        } else {
          final isTeamMove = currentLinkedTeamId != null &&
              currentLinkedTeamId.isNotEmpty &&
              currentLinkedTeamId != team.id;
          memberRef = matches.first.reference;
          memberName = existing.displayName;

          final batch = _firestore.batch();
          _appendUnlinkPreviousMemberToBatch(
            batch: batch,
            currentLinkedTeamId: currentLinkedTeamId,
            currentLinkedMemberId: currentLinkedMemberId,
            nextLinkedTeamId: team.id,
            nextLinkedMemberId: memberRef.id,
          );
          batch.set(
            memberRef,
            {
              'authUid': userId,
              'email': email.trim(),
              'emailLower': emailLower,
              if (isTeamMove) 'positives': 0,
              if (isTeamMove) 'negatives': 0,
            },
            SetOptions(merge: true),
          );
          batch.set(
            _usersRef.doc(userId),
            {
              'linkedTeamId': team.id,
              'linkedMemberId': memberRef.id,
              'linkStatus': 'linked',
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          batch.set(
            _linkRequestsRef.doc(_nextId()),
            {
              'userId': userId,
              'email': email.trim(),
              'name': name,
              'lastName': lastName,
              'teamId': team.id,
              'teamName': team.name,
              'note': note.trim(),
              'status': LinkRequestStatus.approved.name,
              'createdAt': DateTime.now().toIso8601String(),
              'reviewedAt': DateTime.now().toIso8601String(),
              'reviewedByUid': 'system',
              'reviewComment': 'Autoaprobada por configuracion del equipo',
              'memberId': memberRef.id,
              'memberName': memberName,
            },
          );
          await _appendClearDuplicateUserLinksToBatch(
            batch: batch,
            userUid: userId,
            keepTeamId: team.id,
            keepMemberId: memberRef.id,
          );
          await batch.commit();
          return true;
        }
      } else {
        memberRef = _teamsRef.doc(team.id).collection('members').doc(userId);
        final newMember = Member(
          id: memberRef.id,
          name: name.trim().isEmpty ? 'Usuario' : name.trim(),
          lastName: lastName.trim(),
          email: email.trim(),
          emailLower: emailLower,
          authUid: userId,
          role: UserRole.user,
        );
        memberName = newMember.displayName;

        final batch = _firestore.batch();
        _appendUnlinkPreviousMemberToBatch(
          batch: batch,
          currentLinkedTeamId: currentLinkedTeamId,
          currentLinkedMemberId: currentLinkedMemberId,
          nextLinkedTeamId: team.id,
          nextLinkedMemberId: memberRef.id,
        );
        batch.set(memberRef, newMember.toMap(), SetOptions(merge: true));
        batch.set(
          _usersRef.doc(userId),
          {
            'linkedTeamId': team.id,
            'linkedMemberId': memberRef.id,
            'linkStatus': 'linked',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        batch.set(
          _linkRequestsRef.doc(_nextId()),
          {
            'userId': userId,
            'email': email.trim(),
            'name': name,
            'lastName': lastName,
            'teamId': team.id,
            'teamName': team.name,
            'note': note.trim(),
            'status': LinkRequestStatus.approved.name,
            'createdAt': DateTime.now().toIso8601String(),
            'reviewedAt': DateTime.now().toIso8601String(),
            'reviewedByUid': 'system',
            'reviewComment': 'Autoaprobada por configuracion del equipo',
            'memberId': memberRef.id,
            'memberName': memberName,
          },
        );
        await _appendClearDuplicateUserLinksToBatch(
          batch: batch,
          userUid: userId,
          keepTeamId: team.id,
          keepMemberId: memberRef.id,
        );
        await batch.commit();
        return true;
      }
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
    return false;
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
      final userSnap = await tx.get(userRef);

      final liveRequest = LinkRequest.fromMap(linkSnap.id, linkSnap.data()!);
      if (liveRequest.status != LinkRequestStatus.pending) {
        throw Exception('La solicitud ya fue gestionada.');
      }

      final memberSnap = await tx.get(memberRef);
      final userData = userSnap.data() ?? const <String, dynamic>{};
      final currentLinkedTeamId = (userData['linkedTeamId'] as String?)?.trim();
      final isTeamMove = currentLinkedTeamId != null &&
          currentLinkedTeamId.isNotEmpty &&
          currentLinkedTeamId != team.id;
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
        if (isTeamMove) {
          existing.positives = 0;
          existing.negatives = 0;
        }
        memberName = existing.displayName;
        memberData = existing.toMap();
      }

      _unlinkPreviousMemberInTransaction(
        tx: tx,
        userData: userData,
        nextLinkedTeamId: team.id,
        nextLinkedMemberId: memberRef.id,
      );
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
    await _clearDuplicateUserLinksAfterAssociation(
      userUid: request.userId,
      keepTeamId: team.id,
      keepMemberId: memberRef.id,
    );
  }

  Future<List<AppUserRecord>> getUsers() async {
    final docs = await _usersRef.get();
    final users = docs.docs
        .map((doc) => AppUserRecord.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return users;
  }

  Future<void> deleteUserRecord({
    required String userUid,
    required String actorDisplayName,
  }) async {
    final userRef = _usersRef.doc(userUid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) {
      return;
    }
    final user = AppUserRecord.fromMap(userSnap.id, userSnap.data()!);

    final batch = _firestore.batch();
    final deletedMemberPaths = <String>{};
    final teamHistoryAddedFor = <String>{};
    if ((user.linkedTeamId ?? '').isNotEmpty && (user.linkedMemberId ?? '').isNotEmpty) {
      final memberRef = _teamsRef
          .doc(user.linkedTeamId!)
          .collection('members')
          .doc(user.linkedMemberId!);
      deletedMemberPaths.add(memberRef.path);
      if (!teamHistoryAddedFor.contains(user.linkedTeamId)) {
        batch.set(
          _teamsRef.doc(user.linkedTeamId!),
          {
            'teamHistory': FieldValue.arrayUnion([
              HistoryItem(
                '${user.displayName} fue eliminado del equipo por $actorDisplayName',
                DateTime.now(),
              ).toMap(),
            ]),
          },
          SetOptions(merge: true),
        );
        teamHistoryAddedFor.add(user.linkedTeamId!);
      }
      batch.delete(memberRef);
    }

    final linkedMembers = await _findLinkedMemberDocsForUser(userUid);
    for (final linked in linkedMembers) {
      if (deletedMemberPaths.contains(linked.memberRef.path)) {
        continue;
      }
      deletedMemberPaths.add(linked.memberRef.path);
      if (!teamHistoryAddedFor.contains(linked.teamId)) {
        batch.set(
          _teamsRef.doc(linked.teamId),
          {
            'teamHistory': FieldValue.arrayUnion([
              HistoryItem(
                '${linked.memberDisplayName} fue eliminado del equipo por $actorDisplayName',
                DateTime.now(),
              ).toMap(),
            ]),
          },
          SetOptions(merge: true),
        );
        teamHistoryAddedFor.add(linked.teamId);
      }
      batch.delete(linked.memberRef);
    }

    final userRequests = await _linkRequestsRef.where('userId', isEqualTo: userUid).get();
    for (final requestDoc in userRequests.docs) {
      batch.delete(requestDoc.reference);
    }

    batch.delete(userRef);
    await batch.commit();
  }

  Future<void> updateUserRole({
    required String userUid,
    required UserRole role,
    String? linkedTeamId,
  }) async {
    final userRef = _usersRef.doc(userUid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw Exception('Usuario no encontrado.');
    }
    final user = AppUserRecord.fromMap(userSnap.id, userSnap.data()!);

    final requestedLinkedTeamId = linkedTeamId?.trim();
    String? resolvedLinkedTeamId = requestedLinkedTeamId;
    if (requestedLinkedTeamId == null || requestedLinkedTeamId.isEmpty) {
      resolvedLinkedTeamId = null;
    }
    if (role == UserRole.admin) {
      resolvedLinkedTeamId = null;
    }
    if (role == UserRole.gestor) {
      if (resolvedLinkedTeamId == null || resolvedLinkedTeamId.isEmpty) {
        throw Exception('Un gestor debe tener equipo asignado.');
      }
    }
    final shouldClearLinkedMember = user.linkedMemberId != null &&
        user.linkedMemberId!.isNotEmpty &&
        (user.linkedTeamId != resolvedLinkedTeamId || role == UserRole.admin);

    final batch = _firestore.batch();
    batch.set(
      userRef,
      {
        'role': role.name,
        'linkedTeamId': resolvedLinkedTeamId,
        if (shouldClearLinkedMember) 'linkedMemberId': null,
        if (shouldClearLinkedMember) 'linkStatus': 'unlinked',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final teamId = user.linkedTeamId;
    final memberId = user.linkedMemberId;
    if (shouldClearLinkedMember &&
        teamId != null &&
        teamId.isNotEmpty &&
        memberId != null &&
        memberId.isNotEmpty) {
      final oldMemberRef = _teamsRef.doc(teamId).collection('members').doc(memberId);
      batch.set(
        oldMemberRef,
        {
          'authUid': null,
          'positives': 0,
          'negatives': 0,
        },
        SetOptions(merge: true),
      );
    }

    final effectiveTeamId = shouldClearLinkedMember ? null : teamId;
    final effectiveMemberId = shouldClearLinkedMember ? null : memberId;
    if (effectiveTeamId != null &&
        effectiveTeamId.isNotEmpty &&
        effectiveMemberId != null &&
        effectiveMemberId.isNotEmpty) {
      final memberRef = _teamsRef
          .doc(effectiveTeamId)
          .collection('members')
          .doc(effectiveMemberId);
      batch.set(
        memberRef,
        {'role': role.name},
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> updateUserTeamAssociation({
    required String userUid,
    required String? linkedTeamId,
  }) async {
    final userRef = _usersRef.doc(userUid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw Exception('Usuario no encontrado.');
    }
    final user = AppUserRecord.fromMap(userSnap.id, userSnap.data()!);

    final requestedLinkedTeamId = linkedTeamId?.trim();
    String? resolvedLinkedTeamId = requestedLinkedTeamId;
    if (requestedLinkedTeamId == null || requestedLinkedTeamId.isEmpty) {
      resolvedLinkedTeamId = null;
    }
    if (user.role == UserRole.admin) {
      throw Exception('Los administradores no se asocian a equipos.');
    }
    if (user.role == UserRole.gestor &&
        (resolvedLinkedTeamId == null || resolvedLinkedTeamId.isEmpty)) {
      throw Exception('Un gestor debe tener equipo asignado.');
    }

    final hadLinkedMember = user.linkedMemberId != null && user.linkedMemberId!.isNotEmpty;
    final hadLinkedTeam = user.linkedTeamId != null && user.linkedTeamId!.isNotEmpty;

    final batch = _firestore.batch();

    final oldTeamId = user.linkedTeamId;
    final oldMemberId = user.linkedMemberId;
    if (resolvedLinkedTeamId == null || resolvedLinkedTeamId.isEmpty) {
      batch.set(
        userRef,
        {
          'linkedTeamId': null,
          'linkedMemberId': null,
          'linkStatus': 'unlinked',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (hadLinkedMember &&
          hadLinkedTeam &&
          oldTeamId != null &&
          oldTeamId.isNotEmpty &&
          oldMemberId != null &&
          oldMemberId.isNotEmpty) {
        final oldMemberRef = _teamsRef.doc(oldTeamId).collection('members').doc(oldMemberId);
        batch.set(
          oldMemberRef,
          {
            'authUid': null,
            'positives': 0,
            'negatives': 0,
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      return;
    }

    final targetTeamRef = _teamsRef.doc(resolvedLinkedTeamId);
    final targetMembersRef = targetTeamRef.collection('members');

    DocumentReference<Map<String, dynamic>>? targetMemberRef;
    if (user.linkedTeamId == resolvedLinkedTeamId &&
        hadLinkedMember &&
        oldMemberId != null &&
        oldMemberId.isNotEmpty) {
      targetMemberRef = targetMembersRef.doc(oldMemberId);
    } else {
      final byAuthUid = await targetMembersRef
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (byAuthUid.docs.isNotEmpty) {
        targetMemberRef = byAuthUid.docs.first.reference;
      } else {
        final allMembers = await targetMembersRef.get();
        final emailLower = user.email.trim().toLowerCase();
        for (final doc in allMembers.docs) {
          final data = doc.data();
          final docEmailLower = ((data['emailLower'] as String?)?.trim().isNotEmpty ?? false)
              ? (data['emailLower'] as String).trim()
              : ((data['email'] as String?)?.trim().toLowerCase() ?? '');
          final authUid = (data['authUid'] as String?)?.trim() ?? '';
          final canClaim = authUid.isEmpty || authUid == user.uid;
          if (docEmailLower == emailLower && canClaim) {
            targetMemberRef = doc.reference;
            break;
          }
        }
      }
    }

    targetMemberRef ??= targetMembersRef.doc(_nextId());
    final movingFromOtherTeam = hadLinkedTeam &&
        oldTeamId != null &&
        oldTeamId.isNotEmpty &&
        oldTeamId != resolvedLinkedTeamId;

    if (hadLinkedMember &&
        hadLinkedTeam &&
        oldTeamId != null &&
        oldTeamId.isNotEmpty &&
        oldMemberId != null &&
        oldMemberId.isNotEmpty &&
        !(oldTeamId == resolvedLinkedTeamId && oldMemberId == targetMemberRef.id)) {
      final oldMemberRef = _teamsRef.doc(oldTeamId).collection('members').doc(oldMemberId);
      batch.set(
        oldMemberRef,
        {
          'authUid': null,
          'positives': 0,
          'negatives': 0,
        },
        SetOptions(merge: true),
      );
    }

    batch.set(
      targetMemberRef,
      {
        'id': targetMemberRef.id,
        'name': user.name.trim().isEmpty ? user.email : user.name.trim(),
        'lastName': user.lastName.trim(),
        'email': user.email.trim(),
        'emailLower': user.email.trim().toLowerCase(),
        'authUid': user.uid,
        'role': user.role.name,
        if (movingFromOtherTeam) 'positives': 0,
        if (movingFromOtherTeam) 'negatives': 0,
      },
      SetOptions(merge: true),
    );
    batch.set(
      userRef,
      {
        'linkedTeamId': resolvedLinkedTeamId,
        'linkedMemberId': targetMemberRef.id,
        'linkStatus': 'linked',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final linkedMembers = await _findLinkedMemberDocsForUser(user.uid);
    for (final linkedDoc in linkedMembers) {
      final sameTarget =
          linkedDoc.teamId == resolvedLinkedTeamId && linkedDoc.memberRef.id == targetMemberRef.id;
      if (sameTarget) {
        continue;
      }
      batch.set(
        linkedDoc.memberRef,
        {
          'authUid': null,
          'positives': 0,
          'negatives': 0,
        },
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

  void _appendUnlinkPreviousMemberToBatch({
    required WriteBatch batch,
    required String? currentLinkedTeamId,
    required String? currentLinkedMemberId,
    required String nextLinkedTeamId,
    required String nextLinkedMemberId,
  }) {
    if (currentLinkedTeamId == null ||
        currentLinkedTeamId.isEmpty ||
        currentLinkedMemberId == null ||
        currentLinkedMemberId.isEmpty) {
      return;
    }
    final isSameMember = currentLinkedTeamId == nextLinkedTeamId &&
        currentLinkedMemberId == nextLinkedMemberId;
    if (isSameMember) {
      return;
    }
    final previousMemberRef = _teamsRef
        .doc(currentLinkedTeamId)
        .collection('members')
        .doc(currentLinkedMemberId);
    batch.set(
      previousMemberRef,
      {
        'authUid': null,
        'positives': 0,
        'negatives': 0,
      },
      SetOptions(merge: true),
    );
  }

  void _unlinkPreviousMemberInTransaction({
    required Transaction tx,
    required Map<String, dynamic> userData,
    required String nextLinkedTeamId,
    required String nextLinkedMemberId,
  }) {
    final currentLinkedTeamId = (userData['linkedTeamId'] as String?)?.trim();
    final currentLinkedMemberId = (userData['linkedMemberId'] as String?)?.trim();
    if (currentLinkedTeamId == null ||
        currentLinkedTeamId.isEmpty ||
        currentLinkedMemberId == null ||
        currentLinkedMemberId.isEmpty) {
      return;
    }
    final isSameMember = currentLinkedTeamId == nextLinkedTeamId &&
        currentLinkedMemberId == nextLinkedMemberId;
    if (isSameMember) {
      return;
    }
    final previousMemberRef = _teamsRef
        .doc(currentLinkedTeamId)
        .collection('members')
        .doc(currentLinkedMemberId);
    tx.set(
      previousMemberRef,
      {
        'authUid': null,
        'positives': 0,
        'negatives': 0,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _appendClearDuplicateUserLinksToBatch({
    required WriteBatch batch,
    required String userUid,
    required String keepTeamId,
    required String keepMemberId,
  }) async {
    final linkedMembers = await _findLinkedMemberDocsForUser(userUid);
    for (final linkedDoc in linkedMembers) {
      final isTarget = linkedDoc.teamId == keepTeamId && linkedDoc.memberRef.id == keepMemberId;
      if (isTarget) {
        continue;
      }
      batch.set(
        linkedDoc.memberRef,
        {
          'authUid': null,
          'positives': 0,
          'negatives': 0,
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<void> _clearDuplicateUserLinksAfterAssociation({
    required String userUid,
    required String keepTeamId,
    required String keepMemberId,
  }) async {
    final linkedMembers = await _findLinkedMemberDocsForUser(userUid);
    final batch = _firestore.batch();
    var hasChanges = false;
    for (final linkedDoc in linkedMembers) {
      final isTarget = linkedDoc.teamId == keepTeamId && linkedDoc.memberRef.id == keepMemberId;
      if (isTarget) {
        continue;
      }
      hasChanges = true;
      batch.set(
        linkedDoc.memberRef,
        {
          'authUid': null,
          'positives': 0,
          'negatives': 0,
        },
        SetOptions(merge: true),
      );
    }
    if (hasChanges) {
      await batch.commit();
    }
  }

  Future<List<_LinkedMemberRef>> _findLinkedMemberDocsForUser(String userUid) async {
    final teamsSnap = await _teamsRef.get();
    final linked = <_LinkedMemberRef>[];
    for (final teamDoc in teamsSnap.docs) {
      final membersSnap = await teamDoc.reference
          .collection('members')
          .where('authUid', isEqualTo: userUid)
          .get();
      for (final memberDoc in membersSnap.docs) {
        final member = Member.fromMap(memberDoc.data());
        linked.add(
          _LinkedMemberRef(
            teamId: teamDoc.id,
            memberRef: memberDoc.reference,
            memberDisplayName: member.displayName,
          ),
        );
      }
    }
    return linked;
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

class _LinkedMemberRef {
  final String teamId;
  final DocumentReference<Map<String, dynamic>> memberRef;
  final String memberDisplayName;

  const _LinkedMemberRef({
    required this.teamId,
    required this.memberRef,
    required this.memberDisplayName,
  });
}
