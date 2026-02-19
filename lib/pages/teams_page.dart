import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/services/app_data_service.dart';
import 'package:up_down/services/auth_service.dart';
import 'package:up_down/widgets/base_scaffold.dart';
import 'package:up_down/widgets/error_dialog.dart';
import 'package:up_down/widgets/generated_avatar.dart';
import 'package:up_down/widgets/success_snackbar.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  CurrentUserProfile? _currentProfile;
  Member? _currentUser;
  List<Team> _allTeams = [];
  List<Suggestion> _suggestions = [];
  bool _loading = true;
  String? _error;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final currentProfile = await AuthService.instance.getCurrentUserProfile();
      final currentUser = currentProfile.member;
      final snapshot = await AppDataService.instance.loadOrSeed(
        canSeed: currentUser.role == UserRole.admin,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentProfile = currentProfile;
        _currentUser = currentUser;
        _allTeams = snapshot.teams;
        _suggestions = snapshot.suggestions;
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

  Future<void> _persistState() {
    return AppDataService.instance.saveState(_allTeams, _suggestions);
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

    if (_error != null || _currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
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

    final visibleTeams = _visibleTeams();

    return BaseScaffold(
      title: 'Mis equipos',
      args: {
        'currentUser': _currentUser,
        'currentProfile': _currentProfile,
        'teams': _allTeams,
        'suggestions': _suggestions,
      },
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            if (_currentUser!.role == UserRole.admin)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/link-requests');
                    if (mounted) {
                      await _loadData();
                    }
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Solicitudes'),
                ),
              ),
            if (_currentProfile != null && !(_currentProfile!.isLinked))
              Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu cuenta aun no esta vinculada a un integrante.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Solicita vinculacion a un equipo para empezar a usar la app.',
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _allTeams.isEmpty
                            ? null
                            : () => _showCreateLinkRequestDialog(context),
                        icon: const Icon(Icons.send),
                        label: const Text('Solicitar vinculacion'),
                      ),
                    ],
                  ),
                ),
              ),
            if (visibleTeams.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No hay equipos disponibles.')),
              ),
            ...visibleTeams.map((team) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: GeneratedAvatar.rounded(
                    seed: team.id,
                    label: team.name,
                  ),
                  title: Text(team.name),
                  subtitle: Text('${team.members.length} integrantes'),
                  trailing: _currentUser!.role == UserRole.admin
                      ? PopupMenuButton<String>(
                          tooltip: 'Acciones del equipo',
                          onSelected: (value) {
                            if (value == 'rename') {
                              _showRenameTeamDialog(context, team);
                            } else if (value == 'delete') {
                              _confirmDeleteTeam(context, team);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem<String>(
                              value: 'rename',
                              child: Text('Cambiar nombre'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        )
                      : null,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/team-detail',
                      arguments: {
                        'team': team,
                        'currentUser': _currentUser,
                        'currentProfile': _currentProfile,
                        'suggestions': _suggestions,
                        'allTeams': _allTeams,
                      },
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
      floatingActionButton: _currentUser!.role == UserRole.admin
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () => _showAddTeamDialog(context),
            )
          : null,
    );
  }

  void _showAddTeamDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Crear equipo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nombre del equipo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                return;
              }
              Navigator.pop(context);
              await _runAction(() async {
                setState(() {
                  _allTeams.add(Team(name: name, members: []));
                });
                await _persistState();
              });
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  List<Team> _visibleTeams() {
    if (_currentUser == null) {
      return const [];
    }
    if (_currentUser!.role == UserRole.admin) {
      return _allTeams;
    }
    final linkedTeamId = _currentProfile?.linkedTeamId;
    if (linkedTeamId == null || linkedTeamId.isEmpty) {
      return const [];
    }
    return _allTeams.where((team) => team.id == linkedTeamId).toList();
  }

  void _showRenameTeamDialog(BuildContext context, Team team) {
    final controller = TextEditingController(text: team.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambiar nombre del equipo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nuevo nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == team.name) {
                Navigator.pop(context);
                return;
              }

              Navigator.pop(context);
              await _runAction(() async {
                setState(() {
                  final teamIndex = _allTeams.indexWhere(
                    (t) => t.id == team.id,
                  );
                  if (teamIndex >= 0) {
                    _allTeams[teamIndex] = Team(
                      id: team.id,
                      name: newName,
                      members: team.members,
                      isActive: team.isActive,
                      settings: team.settings,
                      teamHistory: team.teamHistory,
                    );
                  }
                  for (final suggestion in _suggestions) {
                    if (suggestion.teamId == team.id) {
                      suggestion.teamName = newName;
                    }
                  }
                });
                await _persistState();
              });

              if (context.mounted) {
                showSuccessSnackBar(context, 'Nombre actualizado');
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTeam(BuildContext context, Team team) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar equipo'),
        content: Text(
          'Se eliminara el equipo ${team.name} y sus integrantes. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await _runAction(() async {
      setState(() {
        _allTeams.removeWhere((t) => t.id == team.id);
        _suggestions.removeWhere((s) => s.teamId == team.id);
      });
      await _persistState();
    });

    if (!context.mounted) {
      return;
    }
    showSuccessSnackBar(context, 'Equipo eliminado');
  }

  void _showCreateLinkRequestDialog(BuildContext context) {
    if (_currentProfile == null || _currentUser == null) {
      return;
    }

    Team selectedTeam = _allTeams.first;
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Solicitar vinculacion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedTeam.id,
                decoration: const InputDecoration(labelText: 'Equipo'),
                items: _allTeams
                    .map(
                      (team) => DropdownMenuItem(
                        value: team.id,
                        child: Text(team.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  final team = _allTeams.firstWhere((t) => t.id == value);
                  setLocalState(() => selectedTeam = team);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
                ),
                minLines: 2,
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                late bool autoApproved;
                try {
                  await _runAction(() async {
                    autoApproved = await AppDataService.instance
                        .createLinkRequest(
                          userId: _currentProfile!.uid,
                          email: _currentProfile!.email,
                          name: _currentUser!.name,
                          lastName: _currentUser!.lastName,
                          team: selectedTeam,
                          note: noteController.text,
                        );
                  });
                } catch (e) {
                  if (!mounted) {
                    return;
                  }
                  await showErrorDialog(
                    this.context,
                    title: 'Error al solicitar vinculacion',
                    error: e,
                  );
                  return;
                }

                if (!mounted) {
                  return;
                }
                showSuccessSnackBar(
                  this.context,
                  autoApproved
                      ? 'Vinculacion autoaprobada'
                      : 'Solicitud enviada al administrador',
                );
                await _loadData();
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}
