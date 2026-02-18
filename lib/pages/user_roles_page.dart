import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:up_down/config/error_titles.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/services/app_data_service.dart';
import 'package:up_down/services/auth_service.dart';
import 'package:up_down/widgets/base_scaffold.dart';
import 'package:up_down/widgets/error_dialog.dart';
import 'package:up_down/widgets/success_snackbar.dart';

class UserRolesPage extends StatefulWidget {
  const UserRolesPage({super.key});

  @override
  State<UserRolesPage> createState() => _UserRolesPageState();
}

class _UserRolesPageState extends State<UserRolesPage> {
  Member? _currentUser;
  CurrentUserProfile? _currentProfile;
  List<Team> _teams = [];
  List<Suggestion> _suggestions = [];
  List<AppUserRecord> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await AuthService.instance.getCurrentUserProfile();
      if (profile.member.role != UserRole.admin) {
        throw Exception('Solo administradores pueden cambiar roles.');
      }

      final snapshot = await AppDataService.instance.loadOrSeed(canSeed: true);
      final users = await AppDataService.instance.getUsers();

      if (!mounted) {
        return;
      }
      setState(() {
        _currentProfile = profile;
        _currentUser = profile.member;
        _teams = snapshot.teams;
        _suggestions = snapshot.suggestions;
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.transparent,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await action();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _currentUser == null || _currentProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Roles de usuarios')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'No se pudo cargar la informacion.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BaseScaffold(
      title: 'Roles de usuarios',
      args: {
        'currentUser': _currentUser,
        'currentProfile': _currentProfile,
        'teams': _teams,
        'suggestions': _suggestions,
      },
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(user.displayName),
                subtitle: Text(user.email),
                trailing: ElevatedButton(
                  onPressed: user.uid == _currentProfile!.uid
                      ? null
                      : () => _showRoleDialog(user),
                  child: const Text('Cambiar rol'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showRoleDialog(AppUserRecord user) {
    UserRole selectedRole = user.role;
    String? selectedTeamId = user.linkedTeamId;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('Rol de ${user.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserRole>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: UserRole.user, child: Text('Usuario')),
                  DropdownMenuItem(value: UserRole.gestor, child: Text('Gestor')),
                  DropdownMenuItem(value: UserRole.admin, child: Text('Administrador')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedRole = value);
                  }
                },
              ),
              if (selectedRole == UserRole.gestor) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedTeamId,
                  decoration: const InputDecoration(labelText: 'Equipo del gestor'),
                  items: _teams
                      .map(
                        (team) => DropdownMenuItem(
                          value: team.id,
                          child: Text(team.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setLocalState(() => selectedTeamId = value);
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedRole == UserRole.gestor &&
                    (selectedTeamId == null || selectedTeamId!.isEmpty)) {
                  await showErrorDialog(
                    this.context,
                    title: ErrorTitles.requiredData,
                    message: 'Selecciona un equipo para el gestor',
                  );
                  return;
                }

                Navigator.pop(context);
                try {
                  await _runAction(() async {
                    await AppDataService.instance.updateUserRole(
                      userUid: user.uid,
                      role: selectedRole,
                      linkedTeamIdForGestor: selectedRole == UserRole.gestor
                          ? selectedTeamId
                          : null,
                    );
                  });
                } catch (e) {
                  if (!mounted) {
                    return;
                  }
                  final details = e is FirebaseException
                      ? 'code=${e.code}\nmessage=${e.message ?? ''}\nraw=$e'
                      : e.toString();
                  await showErrorDialog(
                    this.context,
                    title: ErrorTitles.updateRole,
                    message: details,
                  );
                  return;
                }

                if (!mounted) {
                  return;
                }

                showSuccessSnackBar(this.context, 'Rol actualizado');
                await _loadData();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
