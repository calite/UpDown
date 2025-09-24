import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/widgets/member_card.dart';
import 'package:up_down/widgets/custom_dialog.dart';
import 'package:up_down/widgets/base_scaffold.dart';

enum MemberFilter { all, active }

class TeamDetailsTab extends StatefulWidget {
  final Team team;
  final Member currentUser;
  final List<Team> allTeams;
  final List<Suggestion> suggestions;

  const TeamDetailsTab({
    super.key,
    required this.team,
    required this.currentUser,
    required this.allTeams,
    required this.suggestions,
  });

  @override
  State<TeamDetailsTab> createState() => _TeamDetailsTabState();
}

class _TeamDetailsTabState extends State<TeamDetailsTab> {
  MemberFilter _filter = MemberFilter.all;

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _filter == MemberFilter.all
        ? widget.team.members
        : widget.team.members.where((m) => m.isActive).toList();

    final ranking = List.of(widget.team.members)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final args = {
      'currentUser': widget.currentUser,
      'teams': widget.allTeams,
      'suggestions': widget.suggestions,
    };

    return BaseScaffold(
      title: widget.team.name,
      args: args,
      body: Column(
        children: [
          // 🔹 Botones de filtro
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _filter == MemberFilter.all
                        ? Colors.blue
                        : Colors.grey.shade300,
                  ),
                  onPressed: () {
                    setState(() => _filter = MemberFilter.all);
                  },
                  child: const Text("Todos"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _filter == MemberFilter.active
                        ? Colors.blue
                        : Colors.grey.shade300,
                  ),
                  onPressed: () {
                    setState(() => _filter = MemberFilter.active);
                  },
                  child: const Text("Activos"),
                ),
              ],
            ),
          ),

          // 🔹 Ranking
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
                      "🏆 Ranking por positivos",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (int i = 0; i < ranking.length && i < 3; i++)
                      Text(
                        "${i + 1}. ${ranking[i].name} - ${ranking[i].totalScore} puntos ",
                        style: const TextStyle(fontSize: 14),
                      ),
                  ],
                ),
              ),
            ),

          // 🔹 Lista de miembros
          Expanded(
            child: ListView.builder(
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                return MemberCard(
                  member: member,
                  currentUser: widget.currentUser,
                  team: widget.team,
                  onHistory: () {
                    Navigator.pushNamed(context, '/history', arguments: member);
                  },
                  onSuggestPositive: () {
                    _showSuggestionDialog(context, member, true);
                  },
                  onSuggestNegative: () {
                    _showSuggestionDialog(context, member, false);
                  },
                  onDirectPositive: () {
                    setState(() {
                      widget.team.assignDirect(
                        requester: widget.currentUser,
                        target: member,
                        isPositive: true,
                        comment: "Asignado directo",
                      );
                    });
                  },
                  onDirectNegative: () {
                    setState(() {
                      widget.team.assignDirect(
                        requester: widget.currentUser,
                        target: member,
                        isPositive: false,
                        comment: "Asignado directo",
                      );
                    });
                  },
                  onToggleActive: () {
                    setState(() {
                      member.isActive = !member.isActive;
                      member.history.add(
                        HistoryItem(
                          member.isActive
                              ? "${member.name} fue reactivado"
                              : "${member.name} fue dado de baja",
                          DateTime.now(),
                        ),
                      );
                    });
                  },
                  onMakeAdmin: () {
                    setState(() {
                      member.role = UserRole.admin;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.currentUser.role == UserRole.admin
          ? FloatingActionButton(
              child: const Icon(Icons.person_add),
              onPressed: () {
                _showAddMemberDialog(context, widget.team);
              },
            )
          : null,
    );
  }

  /// 🔹 Diálogo para sugerir positivo/negativo
  void _showSuggestionDialog(
    BuildContext context,
    Member target,
    bool isPositive,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Sugerir ${isPositive ? "positivo" : "negativo"}"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Escribe un comentario...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              final suggestion = Suggestion(
                from: widget.currentUser,
                to: target,
                isPositive: isPositive,
                comment: controller.text,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Sugerencia enviada: ${suggestion.description}",
                  ),
                ),
              );
            },
            child: const Text("Enviar"),
          ),
        ],
      ),
    );
  }

  /// 🔹 Diálogo para añadir miembro
  void _showAddMemberDialog(BuildContext context, Team team) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => CustomDialog(
        title: "Añadir miembro",
        labelText: "Nombre",
        hintText: "Introduce el nombre del miembro",
        confirmText: "Añadir",
        onConfirm: (value) {
          setState(() {
            team.members.add(Member(name: value));
          });
        },
      ),
    );
  }
}
