import 'package:flutter/material.dart';
import 'package:up_down/config/error_titles.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/pages/auth_gate.dart';
import 'package:up_down/services/auth_service.dart';
import 'package:up_down/widgets/error_dialog.dart';
import 'package:up_down/widgets/generated_avatar.dart';

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
            accountName: Text(currentUser.displayName),
            accountEmail: Text(currentUser.role.name),
            currentAccountPicture: GeneratedAvatar.circle(
              seed: currentUser.id,
              label: currentUser.displayName,
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
          if (currentUser.role == UserRole.admin)
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Solicitudes vinculacion'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/link-requests');
              },
            ),
          if (currentUser.role == UserRole.admin)
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Roles de usuarios'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/user-roles');
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesion'),
            onTap: () async {
              Navigator.pop(context);
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                barrierColor: Colors.transparent,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              try {
                await AuthService.instance.signOut();
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context, rootNavigator: true).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false,
                );
              } catch (_) {
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context, rootNavigator: true).pop();
                showErrorDialog(
                  context,
                  title: ErrorTitles.session,
                  message: 'No se pudo cerrar sesion',
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
