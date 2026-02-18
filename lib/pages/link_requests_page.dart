import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/services/app_data_service.dart';
import 'package:up_down/services/auth_service.dart';
import 'package:up_down/widgets/base_scaffold.dart';
import 'package:up_down/widgets/success_snackbar.dart';

class LinkRequestsPage extends StatefulWidget {
  const LinkRequestsPage({super.key});

  @override
  State<LinkRequestsPage> createState() => _LinkRequestsPageState();
}

class _LinkRequestsPageState extends State<LinkRequestsPage> {
  Member? _currentUser;
  CurrentUserProfile? _currentProfile;
  List<Team> _teams = [];
  List<Suggestion> _suggestions = [];
  List<LinkRequest> _requests = [];
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
      final user = profile.member;
      if (user.role != UserRole.admin) {
        throw Exception('Solo administradores pueden gestionar solicitudes.');
      }

      final snapshot = await AppDataService.instance.loadOrSeed(canSeed: true);
      final requests = await AppDataService.instance.getPendingLinkRequests();

      if (!mounted) {
        return;
      }
      setState(() {
        _currentProfile = profile;
        _currentUser = user;
        _teams = snapshot.teams;
        _suggestions = snapshot.suggestions;
        _requests = requests;
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
        appBar: AppBar(title: const Text('Solicitudes de vinculacion')),
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
      title: 'Solicitudes de vinculacion',
      args: {
        'currentUser': _currentUser,
        'currentProfile': _currentProfile,
        'teams': _teams,
        'suggestions': _suggestions,
      },
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _requests.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No hay solicitudes pendientes')),
                ],
              )
            : ListView.builder(
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  final team = _teams
                      .where((t) => t.id == request.teamId)
                      .firstOrNull;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${request.name} ${request.lastName}'.trim(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(request.email),
                          const SizedBox(height: 4),
                          Text('Equipo solicitado: ${request.teamName}'),
                          if (request.note.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Nota: ${request.note}'),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: team == null
                                    ? null
                                    : () => _showApproveDialog(
                                          context,
                                          request,
                                          team,
                                        ),
                                icon: const Icon(Icons.check),
                                label: const Text('Aprobar'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _showRejectDialog(context, request),
                                icon: const Icon(Icons.close),
                                label: const Text('Rechazar'),
                              ),
                            ],
                          ),
                          if (team == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'El equipo solicitado ya no existe.',
                                style: TextStyle(color: Colors.red),
                              ),
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

  void _showApproveDialog(BuildContext context, LinkRequest request, Team team) {
    final members = List<Member>.from(team.members);
    final createId = '__create_new__';
    String selected = createId;
    final nameController = TextEditingController(text: request.name);
    final lastNameController = TextEditingController(text: request.lastName);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) {
          final creating = selected == createId;
          return AlertDialog(
            title: const Text('Aprobar vinculacion'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'Integrante destino',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '__create_new__',
                        child: Text('Crear nuevo integrante'),
                      ),
                      ...members.map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.displayName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setLocalState(() => selected = value);
                      }
                    },
                  ),
                  if (creating) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: 'Apellidos'),
                    ),
                  ],
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
                  Navigator.pop(context);
                  await _runAction(() async {
                    await AppDataService.instance.approveLinkRequest(
                      request: request,
                      adminUid: _currentProfile!.uid,
                      team: team,
                      createNewMember: selected == createId,
                      existingMemberId: selected == createId ? null : selected,
                      newMemberName: nameController.text,
                      newMemberLastName: lastNameController.text,
                    );
                  });
                  if (!mounted) {
                    return;
                  }
                  showSuccessSnackBar(this.context, 'Solicitud aprobada');
                  await _loadData();
                },
                child: const Text('Aprobar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRejectDialog(BuildContext context, LinkRequest request) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _runAction(() async {
                await AppDataService.instance.rejectLinkRequest(
                  request: request,
                  adminUid: _currentProfile!.uid,
                  comment: reasonController.text,
                );
              });
              if (!mounted) {
                return;
              }
              showSuccessSnackBar(this.context, 'Solicitud rechazada');
              await _loadData();
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
