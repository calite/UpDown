import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/mock_data.dart';
import '../widgets/team_card.dart';
import '../widgets/custom_dialog.dart';
import '../widgets/app_drawer.dart'; // importamos el Drawer

enum TeamFilter { all, active }

/// Pantalla que muestra todos los equipos del usuario.
/// Desde aquí se puede: crear equipos, dar de baja/reactivar y navegar al detalle.
class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  TeamFilter _filter = TeamFilter.all;

  @override
  Widget build(BuildContext context) {
    // Filtrar equipos activos/inactivos
    final filteredTeams = _filter == TeamFilter.all
        ? mockTeams
        : mockTeams.where((t) => t.isActive).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Mis Equipos")),
      drawer: const AppDrawer(),
      body: ListView.builder(
        itemCount: filteredTeams.length,
        itemBuilder: (context, index) {
          final team = filteredTeams[index];
          return TeamCard(
            team: team,
            onTap: () {
              Navigator.pushNamed(context, '/team-detail', arguments: team);
            },
            onToggleActive: () {
              setState(() {
                team.isActive = !team.isActive;
              });
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          _showAddTeamDialog(context);
        },
      ),
    );
  }

  /// Diálogo para crear un nuevo equipo
  void _showAddTeamDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CustomDialog(
        title: "Crear nuevo equipo",
        labelText: "Nombre del equipo",
        hintText: "Introduce el nombre",
        confirmText: "Crear",
        onConfirm: (value) {
          setState(() {
            mockTeams.add(Team(name: value, members: []));
          });
        },
      ),
    );
  }
}
