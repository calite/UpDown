import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/data/mock_data.dart';
import 'package:up_down/main.dart'; // para usar HomePage

/// Wrapper intermedio: recibe los argumentos (team, currentUser, suggestions, allTeams)
/// y abre el HomePage con tabs.
class TeamDetailPageWrapper extends StatelessWidget {
  const TeamDetailPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    final Team team = args['team'] as Team;
    final Member currentUser =
        args['currentUser'] as Member? ??
        Member(name: "Invitado", role: UserRole.user);
    final List<Suggestion> suggestions =
        args['suggestions'] as List<Suggestion>? ?? [];
    final List<Team> allTeams = args['allTeams'] as List<Team>? ?? mockTeams;

    return HomePage(
      team: team,
      currentUser: currentUser,
      suggestions: suggestions,
      allTeams: allTeams,
    );
  }
}
