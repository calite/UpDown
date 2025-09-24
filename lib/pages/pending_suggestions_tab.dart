import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/base_scaffold.dart';

/// Pantalla de sugerencias pendientes.
/// Los administradores pueden aceptarlas o rechazarlas con comentario.
/// Los usuarios solo las pueden ver.
class PendingSuggestionsTab extends StatelessWidget {
  final Team team;
  final Member currentUser;
  final List<Suggestion> suggestions;

  const PendingSuggestionsTab({
    super.key,
    required this.team,
    required this.currentUser,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = currentUser.role == UserRole.admin;

    return BaseScaffold(
      title: "📌 Sugerencias pendientes",
      args: {
        'currentUser': currentUser,
        'teams': [team],
        'suggestions': suggestions,
      },
      body: suggestions.isEmpty
          ? const Center(
              child: Text(
                "No hay sugerencias pendientes",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final s = suggestions[index];
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
                      "${s.from.name} → ${s.to.name}",
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
                                tooltip: "Aceptar",
                                onPressed: () {
                                  team.approveSuggestion(currentUser, s);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("✅ Sugerencia aceptada"),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                tooltip: "Rechazar",
                                onPressed: () {
                                  _showRejectDialog(context, s);
                                },
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

  /// Muestra un diálogo para introducir el comentario de rechazo
  void _showRejectDialog(BuildContext context, Suggestion suggestion) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rechazar sugerencia"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Motivo del rechazo (opcional)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              team.rejectSuggestion(
                currentUser,
                suggestion,
                comment: controller.text.isNotEmpty ? controller.text : null,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("❌ Sugerencia rechazada")),
              );
            },
            child: const Text("Rechazar"),
          ),
        ],
      ),
    );
  }
}
