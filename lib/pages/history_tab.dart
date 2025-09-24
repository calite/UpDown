import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/app_drawer.dart';

/// Tab que muestra el historial global de un equipo.
class HistoryTab extends StatelessWidget {
  final Team team;
  final Member currentUser;
  final List<Team> allTeams;
  final List<Suggestion> suggestions;

  const HistoryTab({
    super.key,
    required this.team,
    required this.currentUser,
    required this.allTeams,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    // El historial global se arma a partir de teamHistory
    final historyItems = List<HistoryItem>.from(team.teamHistory)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Historial de ${team.name}"),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: AppDrawer(
        args: {
          'currentUser': currentUser,
          'teams': allTeams,
          'suggestions': suggestions,
        },
      ),
      body: historyItems.isEmpty
          ? const Center(child: Text("No hay historial del equipo"))
          : ListView.builder(
              itemCount: historyItems.length,
              itemBuilder: (context, index) {
                final item = historyItems[index];
                return ListTile(
                  leading: Icon(
                    item.description.contains("rechazada")
                        ? Icons.close
                        : item.description.contains("positivo")
                        ? Icons.thumb_up
                        : item.description.contains("negativo")
                        ? Icons.thumb_down
                        : Icons.info,
                    color: item.description.contains("rechazada")
                        ? Colors.red
                        : item.description.contains("positivo")
                        ? Colors.green
                        : item.description.contains("negativo")
                        ? Colors.red
                        : Colors.grey,
                  ),
                  title: Text(item.description),
                  subtitle: Text(
                    "${item.date.day}/${item.date.month}/${item.date.year} "
                    "${item.date.hour.toString().padLeft(2, '0')}:${item.date.minute.toString().padLeft(2, '0')}",
                  ),
                );
              },
            ),
    );
  }
}
