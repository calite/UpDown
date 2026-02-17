import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/services/app_data_service.dart';
import 'package:up_down/widgets/base_scaffold.dart';

class PendingSuggestionsTab extends StatefulWidget {
  final Team team;
  final Member currentUser;
  final List<Team> allTeams;
  final List<Suggestion> suggestions;

  const PendingSuggestionsTab({
    super.key,
    required this.team,
    required this.currentUser,
    required this.allTeams,
    required this.suggestions,
  });

  @override
  State<PendingSuggestionsTab> createState() => _PendingSuggestionsTabState();
}

class _PendingSuggestionsTabState extends State<PendingSuggestionsTab> {
  Future<void> _persist() {
    return AppDataService.instance.saveState(
      widget.allTeams,
      widget.suggestions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.currentUser.role == UserRole.admin;
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
                      '${s.from.name} -> ${s.to.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(s.comment),
                    trailing: isAdmin
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
                                  setState(() {
                                    widget.team.approveSuggestion(
                                      widget.currentUser,
                                      s,
                                    );
                                    widget.suggestions.remove(s);
                                  });
                                  await _persist();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sugerencia aceptada'),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                tooltip: 'Rechazar',
                                onPressed: () => _showRejectDialog(context, s),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }

  void _showRejectDialog(BuildContext context, Suggestion suggestion) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rechazar sugerencia'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Motivo del rechazo (opcional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                widget.team.rejectSuggestion(
                  widget.currentUser,
                  suggestion,
                  comment: controller.text.isNotEmpty ? controller.text : null,
                );
                widget.suggestions.remove(suggestion);
              });
              await _persist();

              if (!context.mounted) {
                return;
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sugerencia rechazada')),
              );
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }
}
