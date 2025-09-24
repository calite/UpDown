import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic> args;

  const AppDrawer({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final Member currentUser =
        args['currentUser'] as Member? ??
        Member(name: "Invitado", role: UserRole.admin);
    final List<Team> teams = args['teams'] as List<Team>? ?? [];
    final List<Suggestion> suggestions =
        args['suggestions'] as List<Suggestion>? ?? [];

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(currentUser.name),
            accountEmail: Text(currentUser.role.toString().split('.').last),
            currentAccountPicture: const CircleAvatar(
              child: Icon(Icons.person, size: 40),
            ),
          ),

          // =========================
          // Opción: Equipos
          // =========================
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text("Mis equipos"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/teams',
                arguments: {
                  'currentUser': currentUser,
                  'teams': teams,
                  'suggestions': suggestions,
                },
              );
            },
          ),

          // =========================
          // Opción: Estadísticas
          // =========================
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text("Estadísticas"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/stats',
                arguments: {
                  'currentUser': currentUser,
                  'teams': teams,
                  'suggestions': suggestions,
                },
              );
            },
          ),

          // =========================
          // Opción: Configuración
          // =========================
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Configuración"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/settings',
                arguments: {
                  'currentUser': currentUser,
                  'teams': teams,
                  'suggestions': suggestions,
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
