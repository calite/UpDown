import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/pages/home_page.dart';

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
        Member(name: 'Invitado', role: UserRole.user);
    final List<Suggestion> suggestions =
        args['suggestions'] as List<Suggestion>? ?? [];
    final List<Team> allTeams = args['allTeams'] as List<Team>? ?? [];

    return HomePage(
      team: team,
      currentUser: currentUser,
      suggestions: suggestions,
      allTeams: allTeams,
    );
  }
}
