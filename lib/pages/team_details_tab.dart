import 'package:flutter/material.dart';
import 'package:up_down/config/error_titles.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/services/app_data_service.dart';
import 'package:up_down/services/auth_service.dart';
import 'package:up_down/widgets/base_scaffold.dart';
import 'package:up_down/widgets/custom_dialog.dart';
import 'package:up_down/widgets/error_dialog.dart';
import 'package:up_down/widgets/member_card.dart';
import 'package:up_down/widgets/success_snackbar.dart';

enum MemberFilter { all, active, inactive }

class TeamDetailsTab extends StatefulWidget {
  final Team team;
  final Member currentUser;
  final CurrentUserProfile? currentProfile;
  final List<Team> allTeams;
  final List<Suggestion> suggestions;

  const TeamDetailsTab({
    super.key,
    required this.team,
    required this.currentUser,
    required this.currentProfile,
    required this.allTeams,
    required this.suggestions,
  });

  @override
  State<TeamDetailsTab> createState() => _TeamDetailsTabState();
}

class _TeamDetailsTabState extends State<TeamDetailsTab> {
  MemberFilter _filter = MemberFilter.active;

  Future<void> _persist() {
    return AppDataService.instance.saveState(widget.allTeams, widget.suggestions);
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
    final filteredMembers = switch (_filter) {
      MemberFilter.all => widget.team.members,
      MemberFilter.active => widget.team.members.where((m) => m.isActive).toList(),
      MemberFilter.inactive => widget.team.members.where((m) => !m.isActive).toList(),
    };
    final linkedMemberId = widget.currentProfile?.linkedMemberId;
    final linkedMember = linkedMemberId == null
        ? null
        : widget.team.members.where((m) => m.id == linkedMemberId).firstOrNull;
    final actorMember = widget.currentUser.role == UserRole.admin
        ? widget.currentUser
        : (linkedMember ?? widget.currentUser);
    final canSuggestOnTeam = widget.currentUser.role == UserRole.user &&
        (widget.currentProfile?.isLinked ?? false) &&
        widget.currentProfile?.linkedTeamId == widget.team.id &&
        linkedMember != null &&
        linkedMember.isActive;
    final canAssignDirect = (widget.currentUser.role == UserRole.admin ||
            widget.currentUser.role == UserRole.gestor) &&
        actorMember.isActive;

    final ranking = List.of(widget.team.members)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final args = {
      'currentUser': actorMember,
      'currentProfile': widget.currentProfile,
      'teams': widget.allTeams,
      'suggestions': widget.suggestions,
    };

    return BaseScaffold(
      title: widget.team.name,
      args: args,
      body: Column(
        children: [
          if (widget.currentUser.role == UserRole.admin)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: SwitchListTile(
                title: const Text('Autoaprobar solicitudes de vinculacion'),
                subtitle: const Text(
                  'Si esta activo, usuarios nuevos se vinculan al instante cuando sea posible.',
                ),
                value: widget.team.settings.autoApproveJoinRequests,
                onChanged: (value) async {
                  await _runAction(() async {
                    setState(() {
                      widget.team.settings.autoApproveJoinRequests = value;
                    });
                    await _persist();
                  });
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _filter == MemberFilter.active ? Colors.blue : Colors.grey.shade300,
                    foregroundColor:
                        _filter == MemberFilter.active ? Colors.white : Colors.black87,
                    side: BorderSide(
                      color: _filter == MemberFilter.active
                          ? Colors.blue.shade900
                          : Colors.grey.shade400,
                      width: _filter == MemberFilter.active ? 1.5 : 1,
                    ),
                  ),
                  onPressed: () {
                    setState(() => _filter = MemberFilter.active);
                  },
                  child: const Text('Activos'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _filter == MemberFilter.inactive
                        ? Colors.blue
                        : Colors.grey.shade300,
                    foregroundColor: _filter == MemberFilter.inactive
                        ? Colors.white
                        : Colors.black87,
                    side: BorderSide(
                      color: _filter == MemberFilter.inactive
                          ? Colors.blue.shade900
                          : Colors.grey.shade400,
                      width: _filter == MemberFilter.inactive ? 1.5 : 1,
                    ),
                  ),
                  onPressed: () {
                    setState(() => _filter = MemberFilter.inactive);
                  },
                  child: const Text('Inactivos'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _filter == MemberFilter.all ? Colors.blue : Colors.grey.shade300,
                    foregroundColor:
                        _filter == MemberFilter.all ? Colors.white : Colors.black87,
                    side: BorderSide(
                      color: _filter == MemberFilter.all
                          ? Colors.blue.shade900
                          : Colors.grey.shade400,
                      width: _filter == MemberFilter.all ? 1.5 : 1,
                    ),
                  ),
                  onPressed: () {
                    setState(() => _filter = MemberFilter.all);
                  },
                  child: const Text('Todos'),
                ),
              ],
            ),
          ),
          if (ranking.isNotEmpty)
            Card(
              margin: const EdgeInsets.all(10),
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ranking',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    for (int i = 0; i < ranking.length && i < 3; i++)
                      Text(
                        '${i + 1}. ${ranking[i].displayName} - ${ranking[i].totalScore} puntos',
                        style: const TextStyle(fontSize: 14),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                return MemberCard(
                  member: member,
                  currentUser: actorMember,
                  team: widget.team,
                  onHistory: () {
                    Navigator.pushNamed(context, '/history', arguments: member);
                  },
                  onSuggestPositive: canSuggestOnTeam
                      ? () => _showSuggestionDialog(
                            context,
                            member,
                            true,
                            actorMember,
                          )
                      : null,
                  onSuggestNegative: canSuggestOnTeam
                      ? () => _showSuggestionDialog(
                            context,
                            member,
                            false,
                            actorMember,
                          )
                      : null,
                  onDirectPositive: () async {
                    if (!canAssignDirect) {
                      return;
                    }
                    _showDirectAssignDialog(
                      context,
                      target: member,
                      isPositive: true,
                      actorMember: actorMember,
                    );
                  },
                  onDirectNegative: () async {
                    if (!canAssignDirect) {
                      return;
                    }
                    _showDirectAssignDialog(
                      context,
                      target: member,
                      isPositive: false,
                      actorMember: actorMember,
                    );
                  },
                  onToggleActive: () async {
                    await _runAction(() async {
                      setState(() {
                        member.isActive = !member.isActive;
                        final action = member.isActive ? 'reactivado' : 'dado de baja';
                        final now = DateTime.now();
                        member.history.add(
                          HistoryItem(
                            '${member.displayName} fue $action',
                            now,
                          ),
                        );
                        widget.team.teamHistory.add(
                          HistoryItem(
                            '${member.displayName} fue $action por ${actorMember.displayName}',
                            now,
                          ),
                        );
                      });
                      await _persist();
                    });
                  },
                  onMakeGestor: () async {
                    await _runAction(() async {
                      setState(() {
                        member.role = UserRole.gestor;
                      });
                      await _persist();
                    });
                  },
                  backgroundColor: _filter == MemberFilter.all && !member.isActive
                      ? Colors.red.shade50
                      : null,
                  onDeleteMember: () => _confirmDeleteMember(context, member),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.currentUser.role == UserRole.admin
          ? FloatingActionButton(
              child: const Icon(Icons.person_add),
              onPressed: () => _showAddMemberDialog(context, widget.team),
            )
          : null,
    );
  }

  void _showDirectAssignDialog(
    BuildContext context, {
    required Member target,
    required bool isPositive,
    required Member actorMember,
  }) {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Asignar ${isPositive ? 'positivo' : 'negativo'}',
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Comentario obligatorio',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'El comentario es obligatorio';
              }
              return null;
            },
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
              await _runAction(() async {
                setState(() {
                  widget.team.assignDirect(
                    requester: actorMember,
                    target: target,
                    isPositive: isPositive,
                    comment: controller.text.trim(),
                  );
                });
                await _persist();
              });
            },
            child: const Text('Asignar'),
          ),
        ],
      ),
    );
  }

  void _showSuggestionDialog(
    BuildContext context,
    Member target,
    bool isPositive,
    Member actorMember,
  ) {
    final canSuggestOnTeam = widget.currentUser.role == UserRole.user &&
        ((widget.currentProfile?.isLinked ?? false) &&
            widget.currentProfile?.linkedTeamId == widget.team.id &&
            widget.currentProfile?.linkedMemberId == actorMember.id);
    if (!canSuggestOnTeam) {
      showErrorDialog(
        context,
        title: ErrorTitles.forbiddenAction,
        message: 'No tienes permiso para sugerir en este equipo.',
      );
      return;
    }

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sugerir ${isPositive ? 'positivo' : 'negativo'}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Escribe un comentario...',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'El comentario es obligatorio';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              final suggestion = Suggestion(
                from: actorMember,
                to: target,
                isPositive: isPositive,
                comment: controller.text.trim(),
                teamId: widget.team.id,
                teamName: widget.team.name,
              );

              Navigator.pop(context);
              await _runAction(() async {
                setState(() {
                  widget.suggestions.add(suggestion);
                  widget.team.addSuggestion(suggestion);
                });
                await AppDataService.instance.addSuggestion(suggestion);
              });

              if (!context.mounted) {
                return;
              }
              showSuccessSnackBar(
                context,
                'Sugerencia enviada: ${suggestion.description}',
              );
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, Team team) {
    showDialog(
      context: context,
      builder: (_) => CustomDialog(
        title: 'Anadir miembro',
        labelText: 'Nombre',
        hintText: 'Introduce el nombre del miembro',
        confirmText: 'Anadir',
        onConfirm: (value) async {
          await _runAction(() async {
            setState(() {
              team.members.add(Member(name: value));
            });
            await _persist();
          });
        },
      ),
    );
  }

  Future<void> _confirmDeleteMember(BuildContext context, Member member) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar integrante'),
        content: Text(
          'Se eliminara a ${member.displayName} del equipo. Continuar?',
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
        widget.team.teamHistory.add(
          HistoryItem(
            '${member.displayName} fue eliminado del equipo por ${widget.currentUser.displayName}',
            DateTime.now(),
          ),
        );
        widget.team.members.removeWhere((m) => m.id == member.id);
        widget.suggestions.removeWhere(
          (s) => s.to.id == member.id || s.from.id == member.id,
        );
        widget.team.pendingSuggestions.removeWhere(
          (s) => s.to.id == member.id || s.from.id == member.id,
        );
      });
      await _persist();
    });

    if (!context.mounted) {
      return;
    }
    showSuccessSnackBar(context, 'Integrante eliminado');
  }

}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
