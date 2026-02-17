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

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _teamsRef =>
      _firestore.collection('teams');

  CollectionReference<Map<String, dynamic>> get _suggestionsRef =>
      _firestore.collection('suggestions');

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
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
