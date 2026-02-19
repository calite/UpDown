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
  String _search = '';
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
        appBar: AppBar(title: const Text('Usuarios')),
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
      title: 'Usuarios',
      args: {
        'currentUser': _currentUser,
        'currentProfile': _currentProfile,
        'teams': _teams,
        'suggestions': _suggestions,
      },
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          itemCount: _filteredUsers().length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Buscar usuarios',
                    hintText: 'Nombre, apellido o email',
                  ),
                  onChanged: (value) {
                    setState(() => _search = value);
                  },
                ),
              );
            }

            final user = _filteredUsers()[index - 1];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(user.email),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: user.uid == _currentProfile!.uid
                                    ? null
                                    : () => _showRoleDialog(user),
                                icon: const Icon(Icons.manage_accounts),
                                label: Text('Rol: ${_roleLabel(user.role)}'),
                                style: OutlinedButton.styleFrom(
                                  shape: const StadiumBorder(),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showTeamDialog(user),
                                icon: const Icon(Icons.group),
                                label: Text(
                                  'Equipo: ${_teamLabel(user.role, user.linkedTeamId)}',
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: const StadiumBorder(),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showEditUserDialog(user),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar datos'),
                                style: OutlinedButton.styleFrom(
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: user.uid == _currentProfile!.uid
                              ? null
                              : () => _confirmDeleteUser(user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  ],
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
                  DropdownMenuItem(
                    value: UserRole.user,
                    child: Text('Usuario'),
                  ),
                  DropdownMenuItem(
                    value: UserRole.gestor,
                    child: Text('Gestor'),
                  ),
                  DropdownMenuItem(
                    value: UserRole.admin,
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedRole = value);
                  }
                },
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
                String? roleLinkedTeamId = user.linkedTeamId;
                if (selectedRole == UserRole.gestor &&
                    (roleLinkedTeamId == null || roleLinkedTeamId.isEmpty)) {
                  final roleSelection = await _showTeamPickerDialog(
                    title: 'Equipo para gestor',
                    labelText: 'Selecciona un equipo',
                    initialTeamId: roleLinkedTeamId,
                    allowEmpty: false,
                  );
                  if (roleSelection == null || !roleSelection.confirmed) {
                    return;
                  }
                  roleLinkedTeamId = roleSelection.teamId;
                  if (roleLinkedTeamId == null || roleLinkedTeamId.isEmpty) {
                    return;
                  }
                }
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                try {
                  await _runAction(() async {
                    await AppDataService.instance.updateUserRole(
                      userUid: user.uid,
                      role: selectedRole,
                      linkedTeamId: roleLinkedTeamId,
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

  Future<void> _confirmDeleteUser(AppUserRecord user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text(
          'Se eliminara el usuario ${user.displayName}. Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await _runAction(() async {
        await AppDataService.instance.deleteUserRecord(
          userUid: user.uid,
          actorDisplayName: _currentUser?.displayName ?? 'Administrador',
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
        context,
        title: 'Error al eliminar usuario',
        message: details,
      );
      return;
    }

    if (!mounted) {
      return;
    }
    showSuccessSnackBar(context, 'Usuario eliminado');
    await _loadData();
  }

  void _showTeamDialog(AppUserRecord user) {
    _showTeamPickerDialog(
      title: 'Equipo de ${user.displayName}',
      labelText: user.role == UserRole.gestor
          ? 'Equipo del gestor'
          : 'Equipo asociado (opcional)',
      initialTeamId: user.linkedTeamId,
      allowEmpty: user.role != UserRole.gestor,
    ).then((selection) async {
      if (selection == null || !selection.confirmed) {
        return;
      }
      final selectedTeamId = selection.teamId;
      if (selectedTeamId == null && user.role == UserRole.gestor) {
        return;
      }
      final plan = await _buildAssociationPlan(
        user: user,
        selectedTeamId: selectedTeamId,
      );
      if (plan == null) {
        return;
      }
      try {
        await _runAction(() async {
          await AppDataService.instance.updateUserTeamAssociation(
            userUid: user.uid,
            linkedTeamId: plan.linkedTeamId,
            forcedMemberId: plan.forcedMemberId,
            forceCreateNewMember: plan.forceCreateNewMember,
            newMemberName: plan.newMemberName,
            newMemberLastName: plan.newMemberLastName,
            newMemberAlias: plan.newMemberAlias,
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
          context,
          title: ErrorTitles.updateRole,
          message: details,
        );
        return;
      }

      if (!mounted) {
        return;
      }
      showSuccessSnackBar(context, 'Equipo actualizado');
      await _loadData();
    });
  }

  Future<_TeamAssociationPlan?> _buildAssociationPlan({
    required AppUserRecord user,
    required String? selectedTeamId,
  }) async {
    if (selectedTeamId == null || selectedTeamId.isEmpty) {
      return const _TeamAssociationPlan(linkedTeamId: null);
    }

    final team = _teams.where((t) => t.id == selectedTeamId).firstOrNull;
    if (team == null) {
      await showErrorDialog(
        context,
        title: ErrorTitles.requiredData,
        message: 'El equipo seleccionado no existe.',
      );
      return null;
    }

    if (_canAssociateByEmail(user: user, team: team)) {
      return _TeamAssociationPlan(linkedTeamId: selectedTeamId);
    }

    final choice = await _showAssociationTargetDialog(team: team);
    if (choice == null || !choice.confirmed) {
      return null;
    }

    if (!choice.createNewMember) {
      return _TeamAssociationPlan(
        linkedTeamId: selectedTeamId,
        forcedMemberId: choice.memberId,
      );
    }

    final createData = await _showCreateMemberDialog(user: user, team: team);
    if (createData == null || !createData.confirmed) {
      return null;
    }

    return _TeamAssociationPlan(
      linkedTeamId: selectedTeamId,
      forceCreateNewMember: true,
      newMemberName: createData.name,
      newMemberLastName: createData.lastName,
      newMemberAlias: createData.alias,
    );
  }

  bool _canAssociateByEmail({required AppUserRecord user, required Team team}) {
    final emailLower = user.email.trim().toLowerCase();
    for (final member in team.members) {
      final candidateEmail = member.emailLower.trim().isNotEmpty
          ? member.emailLower.trim()
          : member.email.trim().toLowerCase();
      final authUid = (member.authUid ?? '').trim();
      final canClaim = authUid.isEmpty || authUid == user.uid;
      if (candidateEmail == emailLower && canClaim) {
        return true;
      }
    }
    return false;
  }

  Future<_AssociationTargetChoice?> _showAssociationTargetDialog({
    required Team team,
  }) {
    final availableMembers =
        team.members.where((m) => (m.authUid ?? '').trim().isEmpty).toList()
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );

    const createId = '__create_new_member__';
    String selectedId = availableMembers.isNotEmpty
        ? availableMembers.first.id
        : createId;

    return showDialog<_AssociationTargetChoice>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('No se encontro integrante por email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Selecciona un integrante libre del equipo o crea uno nuevo.',
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: const InputDecoration(
                  labelText: 'Integrante destino',
                ),
                items: [
                  ...availableMembers.map(
                    (m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.displayName),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: createId,
                    child: Text('Crear nuevo integrante'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedId = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                const _AssociationTargetChoice.cancelled(),
              ),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedId == createId) {
                  Navigator.pop(
                    context,
                    const _AssociationTargetChoice.createNew(),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  _AssociationTargetChoice.existing(selectedId),
                );
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_CreateMemberDialogResult?> _showCreateMemberDialog({
    required AppUserRecord user,
    required Team team,
  }) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.name);
    final lastNameController = TextEditingController(text: user.lastName);
    final aliasController = TextEditingController(text: user.alias);

    return showDialog<_CreateMemberDialogResult>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nuevo integrante en ${team.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: lastNameController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Apellido'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: aliasController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Alias'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const _CreateMemberDialogResult.cancelled(),
            ),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) {
                return;
              }
              Navigator.pop(
                context,
                _CreateMemberDialogResult.confirmed(
                  name: nameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  alias: aliasController.text.trim(),
                ),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<_TeamPickerResult?> _showTeamPickerDialog({
    required String title,
    required String labelText,
    required String? initialTeamId,
    required bool allowEmpty,
  }) {
    String? selectedTeamId = initialTeamId;
    return showDialog<_TeamPickerResult>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(title),
          content: DropdownButtonFormField<String?>(
            initialValue: selectedTeamId,
            decoration: InputDecoration(labelText: labelText),
            items: [
              if (allowEmpty)
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin equipo asociado'),
                ),
              ..._teams.map(
                (team) => DropdownMenuItem<String?>(
                  value: team.id,
                  child: Text(team.name),
                ),
              ),
            ],
            onChanged: (value) {
              setLocalState(() => selectedTeamId = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, const _TeamPickerResult.cancelled()),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!allowEmpty &&
                    (selectedTeamId == null || selectedTeamId!.isEmpty)) {
                  await showErrorDialog(
                    this.context,
                    title: ErrorTitles.requiredData,
                    message: 'Selecciona un equipo para continuar',
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  _TeamPickerResult.confirmed(selectedTeamId),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(AppUserRecord user) {
    final linkedMember = _findLinkedMember(user);
    final canEditEmail =
        linkedMember == null || (linkedMember.authUid ?? '').trim().isEmpty;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.name);
    final lastNameController = TextEditingController(text: user.lastName);
    final aliasController = TextEditingController(text: user.alias);
    final emailController = TextEditingController(text: user.email);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar usuario: ${user.displayName}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: lastNameController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Apellido'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: aliasController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Alias'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailController,
                enabled: canEditEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  helperText: canEditEmail
                      ? null
                      : 'No editable: ya existe un usuario vinculado',
                ),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) {
                    return 'El email es obligatorio';
                  }
                  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                  if (!emailRegex.hasMatch(email)) {
                    return 'Email no valido';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              Navigator.pop(context);
              try {
                await _runAction(() async {
                  await AppDataService.instance.updateUserBasicData(
                    userUid: user.uid,
                    name: nameController.text.trim(),
                    lastName: lastNameController.text.trim(),
                    alias: aliasController.text.trim(),
                    email: emailController.text.trim(),
                    canEditEmail: canEditEmail,
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
                  context,
                  title: 'Error al actualizar usuario',
                  message: details,
                );
                return;
              }

              if (!mounted) {
                return;
              }
              showSuccessSnackBar(context, 'Datos actualizados');
              await _loadData();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Member? _findLinkedMember(AppUserRecord user) {
    final teamId = user.linkedTeamId?.trim();
    final memberId = user.linkedMemberId?.trim();
    if (teamId == null ||
        teamId.isEmpty ||
        memberId == null ||
        memberId.isEmpty) {
      return null;
    }
    final team = _teams.where((t) => t.id == teamId).firstOrNull;
    if (team == null) {
      return null;
    }
    return team.members.where((m) => m.id == memberId).firstOrNull;
  }

  List<AppUserRecord> _filteredUsers() {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) {
      return _users;
    }
    return _users.where((user) {
      return user.name.toLowerCase().contains(query) ||
          user.lastName.toLowerCase().contains(query) ||
          user.alias.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.gestor:
        return 'Gestor';
      case UserRole.user:
        return 'Usuario';
    }
  }

  String _teamLabel(UserRole role, String? teamId) {
    if (teamId == null || teamId.isEmpty) {
      return role == UserRole.admin ? 'Todos (sin asignar)' : 'Sin equipo';
    }
    final team = _teams.where((t) => t.id == teamId).firstOrNull;
    final teamName = team?.name ?? 'Sin equipo';
    if (role == UserRole.admin) {
      return 'Todos (asignado: $teamName)';
    }
    return teamName;
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

class _TeamPickerResult {
  final bool confirmed;
  final String? teamId;

  const _TeamPickerResult._({required this.confirmed, required this.teamId});

  const _TeamPickerResult.cancelled() : this._(confirmed: false, teamId: null);

  const _TeamPickerResult.confirmed(String? teamId)
    : this._(confirmed: true, teamId: teamId);
}

class _TeamAssociationPlan {
  final String? linkedTeamId;
  final String? forcedMemberId;
  final bool forceCreateNewMember;
  final String? newMemberName;
  final String? newMemberLastName;
  final String? newMemberAlias;

  const _TeamAssociationPlan({
    required this.linkedTeamId,
    this.forcedMemberId,
    this.forceCreateNewMember = false,
    this.newMemberName,
    this.newMemberLastName,
    this.newMemberAlias,
  });
}

class _AssociationTargetChoice {
  final bool confirmed;
  final bool createNewMember;
  final String? memberId;

  const _AssociationTargetChoice._({
    required this.confirmed,
    required this.createNewMember,
    required this.memberId,
  });

  const _AssociationTargetChoice.cancelled()
    : this._(confirmed: false, createNewMember: false, memberId: null);

  const _AssociationTargetChoice.createNew()
    : this._(confirmed: true, createNewMember: true, memberId: null);

  const _AssociationTargetChoice.existing(String memberId)
    : this._(confirmed: true, createNewMember: false, memberId: memberId);
}

class _CreateMemberDialogResult {
  final bool confirmed;
  final String name;
  final String lastName;
  final String alias;

  const _CreateMemberDialogResult._({
    required this.confirmed,
    required this.name,
    required this.lastName,
    required this.alias,
  });

  const _CreateMemberDialogResult.cancelled()
    : this._(confirmed: false, name: '', lastName: '', alias: '');

  const _CreateMemberDialogResult.confirmed({
    required String name,
    required String lastName,
    required String alias,
  }) : this._(confirmed: true, name: name, lastName: lastName, alias: alias);
}
