import 'package:flutter/material.dart';
import 'package:up_down/widgets/app_drawer.dart';
import '../models/models.dart';
import '../widgets/member_card.dart';
import '../widgets/custom_dialog.dart';

enum MemberFilter { all, active }

class TeamDetailPage extends StatefulWidget {
  const TeamDetailPage({super.key});

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  MemberFilter _filter = MemberFilter.all;

  @override
  Widget build(BuildContext context) {
    final team = ModalRoute.of(context)!.settings.arguments as Team;

    // Filtramos miembros según el estado del filtro
    final filteredMembers = _filter == MemberFilter.all
        ? team.members
        : team.members.where((m) => m.isActive).toList();

    // Creamos el ranking: ordenamos por totalScore de mayor a menor
    final ranking = List.of(team.members)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        actions: [
          DropdownButton<MemberFilter>(
            value: _filter,
            underline: const SizedBox(),
            icon: const Icon(Icons.filter_list, color: Colors.white),
            dropdownColor: Colors.white,
            items: const [
              DropdownMenuItem(value: MemberFilter.all, child: Text("Todos")),
              DropdownMenuItem(
                value: MemberFilter.active,
                child: Text("Solo activos"),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _filter = value!;
              });
            },
          ),
        ],
      ),
      drawer: const AppDrawer(), //Drawer
      body: Column(
        children: [
          // Bloque del ranking
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
                    // Mostramos el top 3 (o menos si hay pocos miembros)
                    for (int i = 0; i < ranking.length && i < 3; i++)
                      Text(
                        "${i + 1}. ${ranking[i].name} - ${ranking[i].totalScore} puntos ",
                        style: const TextStyle(fontSize: 14),
                      ),
                  ],
                ),
              ),
            ),

          // Lista de miembros normal (expandida para ocupar el resto de la pantalla)
          Expanded(
            child: ListView.builder(
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                return MemberCard(
                  member: member,
                  onPositive: () {
                    setState(() {
                      member.positives++;
                      member.history.add(
                        HistoryItem(
                          "${member.name} recibió +1 (sugerido)",
                          DateTime.now(),
                        ),
                      );
                    });
                  },
                  onNegative: () {
                    setState(() {
                      member.negatives++;
                      member.history.add(
                        HistoryItem(
                          "${member.name} recibió -1 (sugerido)",
                          DateTime.now(),
                        ),
                      );
                    });
                  },
                  onHistory: () {
                    Navigator.pushNamed(context, '/history', arguments: member);
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          _showAddMemberDialog(context, team);
        },
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, Team team) {
    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: "Añadir miembro",
        labelText: "Nombre",
        hintText: "Introduce el nombre del miembro",
        confirmText: "Añadir",
        onConfirm: (value) {
          setState(() {
            team.members.add(Member(name: value, positives: 0, negatives: 0));
          });
        },
      ),
    );
  }
}
