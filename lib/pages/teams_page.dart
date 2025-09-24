import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/data/mock_data.dart';
import 'package:up_down/widgets/base_scaffold.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final Member currentUser =
        args?['currentUser'] as Member? ??
        Member(name: "Invitado", role: UserRole.admin);
    final List<Team> allTeams = args?['allTeams'] as List<Team>? ?? mockTeams;
    final List<Suggestion> suggestions =
        args?['suggestions'] as List<Suggestion>? ?? [];

    return BaseScaffold(
      title: "Mis equipos",
      args: {
        'currentUser': currentUser,
        'teams': allTeams,
        'suggestions': suggestions,
      },
      body: ListView.builder(
        itemCount: allTeams.length,
        itemBuilder: (context, index) {
          final team = allTeams[index];
          return ListTile(
            leading: const Icon(Icons.group),
            title: Text(team.name),
            subtitle: Text("${team.members.length} miembros"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/team-detail',
                arguments: {
                  'team': team,
                  'currentUser': currentUser,
                  'suggestions': suggestions,
                  'allTeams': allTeams,
                },
              );
            },
          );
        },
      ),
      floatingActionButton: currentUser.role == UserRole.admin
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () {
                _showAddTeamDialog(context, allTeams);
              },
            )
          : null,
    );
  }

  void _showAddTeamDialog(BuildContext context, List<Team> allTeams) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Crear equipo"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nombre del equipo"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                allTeams.add(Team(name: controller.text, members: []));
              });
              Navigator.pop(context);
            },
            child: const Text("Crear"),
          ),
        ],
      ),
    );
  }
}
