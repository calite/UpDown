import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/pages/history_tab.dart';
import 'package:up_down/pages/pending_suggestions_tab.dart';
import 'package:up_down/pages/team_details_tab.dart';
import 'package:up_down/services/auth_service.dart';

class HomePage extends StatefulWidget {
  final Team team;
  final Member currentUser;
  final CurrentUserProfile? currentProfile;
  final List<Suggestion> suggestions;
  final List<Team> allTeams;

  const HomePage({
    super.key,
    required this.team,
    required this.currentUser,
    this.currentProfile,
    required this.suggestions,
    required this.allTeams,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  Member _resolveActingMember() {
    if (widget.currentUser.role == UserRole.admin) {
      return widget.currentUser;
    }
    final linkedMemberId = widget.currentProfile?.linkedMemberId;
    final linkedTeamId = widget.currentProfile?.linkedTeamId;
    if (linkedMemberId == null || linkedMemberId.isEmpty) {
      return widget.currentUser;
    }
    if (linkedTeamId != widget.team.id) {
      return widget.currentUser;
    }
    return widget.team.members
            .where((m) => m.id == linkedMemberId)
            .firstOrNull ??
        widget.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    final actingMember = _resolveActingMember();

    final pages = [
      TeamDetailsTab(
        team: widget.team,
        currentUser: actingMember,
        currentProfile: widget.currentProfile,
        allTeams: widget.allTeams,
        suggestions: widget.suggestions,
      ),
      PendingSuggestionsTab(
        team: widget.team,
        currentUser: actingMember,
        currentProfile: widget.currentProfile,
        allTeams: widget.allTeams,
        suggestions: widget.suggestions,
      ),
      HistoryTab(
        team: widget.team,
        currentUser: actingMember,
        currentProfile: widget.currentProfile,
        allTeams: widget.allTeams,
        suggestions: widget.suggestions,
      ),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Miembros'),
          BottomNavigationBarItem(
            icon: Icon(Icons.pending_actions),
            label: 'Sugerencias',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historico',
          ),
        ],
      ),
    );
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
