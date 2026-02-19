import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/services/app_data_service.dart';
import 'package:up_down/services/auth_service.dart';
import 'package:up_down/widgets/error_dialog.dart';
import 'package:up_down/config/error_titles.dart';
import 'package:up_down/widgets/base_scaffold.dart';
import 'package:up_down/widgets/success_snackbar.dart';

class PendingSuggestionsTab extends StatefulWidget {
  final Team team;
  final Member currentUser;
  final CurrentUserProfile? currentProfile;
  final List<Team> allTeams;
  final List<Suggestion> suggestions;

  const PendingSuggestionsTab({
    super.key,
    required this.team,
    required this.currentUser,
    required this.currentProfile,
    required this.allTeams,
    required this.suggestions,
  });

  @override
  State<PendingSuggestionsTab> createState() => _PendingSuggestionsTabState();
}

class _PendingSuggestionsTabState extends State<PendingSuggestionsTab> {
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
    final canManageSuggestions =
        widget.currentUser.role == UserRole.admin ||
        (widget.currentUser.role == UserRole.gestor &&
            widget.currentProfile?.linkedTeamId == widget.team.id);
    final teamSuggestions = widget.suggestions
        .where((s) => s.teamId == widget.team.id)
        .toList();

    return BaseScaffold(
      title: 'Sugerencias pendientes',
      args: {
        'currentUser': widget.currentUser,
        'teams': widget.allTeams,
        'suggestions': widget.suggestions,
      },
      body: teamSuggestions.isEmpty
          ? const Center(
              child: Text(
                'No hay sugerencias pendientes',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: teamSuggestions.length,
              itemBuilder: (context, index) {
                final s = teamSuggestions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 12,
                  ),
                  child: ListTile(
                    leading: Icon(
                      s.isPositive ? Icons.thumb_up : Icons.thumb_down,
                      color: s.isPositive ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      '${s.from.displayName} -> ${s.to.displayName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(s.comment, textAlign: TextAlign.center),
                    trailing: canManageSuggestions
                        ? Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                tooltip: 'Aceptar',
                                onPressed: () async {
                                  try {
                                    await _runAction(() async {
                                      await AppDataService.instance
                                          .approveSuggestionWithEffects(
                                            suggestion: s,
                                            reviewer: widget.currentUser,
                                          );
                                      setState(() {
                                        widget.team.approveSuggestion(
                                          widget.currentUser,
                                          s,
                                        );
                                        widget.suggestions.remove(s);
                                      });
                                    });
                                  } catch (e) {
                                    if (context.mounted) {
                                      await showErrorDialog(
                                        context,
                                        title: ErrorTitles.forbiddenAction,
                                        error: e,
                                      );
                                    }
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  showSuccessSnackBar(
                                    context,
                                    'Sugerencia aceptada',
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                tooltip: 'Rechazar',
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Rechazar sugerencia'),
                                      content: const Text(
                                        'Se rechazara esta sugerencia. Continuar?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Rechazar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) {
                                    return;
                                  }
                                  try {
                                    await _runAction(() async {
                                      await AppDataService.instance
                                          .rejectSuggestionWithEffects(
                                            suggestion: s,
                                            reviewer: widget.currentUser,
                                          );
                                      setState(() {
                                        widget.team.rejectSuggestion(
                                          widget.currentUser,
                                          s,
                                        );
                                        widget.suggestions.remove(s);
                                      });
                                    });
                                  } catch (e) {
                                    if (context.mounted) {
                                      await showErrorDialog(
                                        context,
                                        title: ErrorTitles.forbiddenAction,
                                        error: e,
                                      );
                                    }
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  showSuccessSnackBar(
                                    context,
                                    'Sugerencia rechazada',
                                  );
                                },
                              ),
                            ],
                          )
                        : (s.from.id == widget.currentUser.id
                              ? IconButton(
                                  icon: const Icon(Icons.cancel_outlined),
                                  tooltip: 'Cancelar sugerencia',
                                  onPressed: () async {
                                    await _runAction(() async {
                                      setState(() {
                                        widget.suggestions.removeWhere(
                                          (item) => item.id == s.id,
                                        );
                                        widget.team.pendingSuggestions
                                            .removeWhere(
                                              (item) => item.id == s.id,
                                            );
                                      });
                                      await AppDataService.instance
                                          .deleteSuggestion(s.id);
                                    });
                                    if (!context.mounted) {
                                      return;
                                    }
                                    showSuccessSnackBar(
                                      context,
                                      'Sugerencia cancelada',
                                    );
                                  },
                                )
                              : null),
                  ),
                );
              },
            ),
    );
  }
}
