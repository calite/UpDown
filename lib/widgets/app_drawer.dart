import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/pages/auth_gate.dart';
import 'package:up_down/services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic> args;

  const AppDrawer({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final Member currentUser =
        args['currentUser'] as Member? ??
        Member(name: 'Invitado', role: UserRole.user);
    final List<Team> teams = args['teams'] as List<Team>? ?? [];
    final List<Suggestion> suggestions =
        args['suggestions'] as List<Suggestion>? ?? [];

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(currentUser.name),
            accountEmail: Text(currentUser.role.name),
            currentAccountPicture: const CircleAvatar(
              child: Icon(Icons.person, size: 40),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Mis equipos'),
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
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Estadisticas'),
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
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuracion'),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesion'),
            onTap: () async {
              Navigator.pop(context);
              await AuthService.instance.signOut();
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthGate()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
