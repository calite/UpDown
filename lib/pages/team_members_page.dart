import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';

/// Pantalla principal para ver los miembros de un equipo.
class TeamMembersPage extends StatelessWidget {
  final Team team;
  final Member currentUser; // el usuario logueado

  const TeamMembersPage({
    super.key,
    required this.team,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Miembros de ${team.name}"),
      ),
      body: ListView.builder(
        itemCount: team.members.length,
        itemBuilder: (context, index) {
          final member = team.members[index];
          return MemberCard(
            member: member,
            currentUser: currentUser,
            team: team,
          );
        },
      ),
    );
  }
}

/// Widget que muestra un miembro con sus datos y acciones disponibles.
class MemberCard extends StatelessWidget {
  final Member member;
  final Member currentUser;
  final Team team;

  const MemberCard({
    super.key,
    required this.member,
    required this.currentUser,
    required this.team,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Row(
          children: [
            Text(
              member.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            // Badge de rol
            Chip(
              label: Text(
                member.role == UserRole.admin ? "Admin" : "User",
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: member.role == UserRole.admin
                  ? Colors.blue
                  : Colors.grey,
            ),
          ],
        ),
        subtitle: Text(
          "Positivos: ${member.positives}, "
          "Negativos: ${member.negatives}, "
          "Puntaje: ${member.totalScore}",
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case "sugerir_positivo":
                _showSuggestionDialog(context, true);
                break;
              case "sugerir_negativo":
                _showSuggestionDialog(context, false);
                break;
              case "asignar_positivo":
                _showDirectAssignDialog(context, true);
                break;
              case "asignar_negativo":
                _showDirectAssignDialog(context, false);
                break;
              case "hacer_admin":
                _makeAdmin(context);
                break;
              case "ver_historial":
                _showHistory(context);
                break;
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];

            // Si soy usuario normal y estoy viendo a otro miembro → puedo sugerir
            if (currentUser.role == UserRole.user && currentUser != member) {
              items.add(
                const PopupMenuItem(
                  value: "sugerir_positivo",
                  child: Text("Sugerir positivo"),
                ),
              );
              items.add(
                const PopupMenuItem(
                  value: "sugerir_negativo",
                  child: Text("Sugerir negativo"),
                ),
              );
            }

            // Si soy admin y no soy yo → puedo asignar directos
            if (currentUser.role == UserRole.admin && currentUser != member) {
              items.add(
                const PopupMenuItem(
                  value: "asignar_positivo",
                  child: Text("Asignar positivo"),
                ),
              );
              items.add(
                const PopupMenuItem(
                  value: "asignar_negativo",
                  child: Text("Asignar negativo"),
                ),
              );
              // Convertir en admin
              if (member.role != UserRole.admin) {
                items.add(
                  const PopupMenuItem(
                    value: "hacer_admin",
                    child: Text("Hacer admin"),
                  ),
                );
              }
            }

            // Ver historial siempre disponible
            items.add(
              const PopupMenuItem(
                value: "ver_historial",
                child: Text("Ver historial"),
              ),
            );

            return items;
          },
        ),
      ),
    );
  }

  /// Muestra un diálogo para sugerir positivo/negativo
  void _showSuggestionDialog(BuildContext context, bool isPositive) {
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
                from: currentUser,
                to: member,
                isPositive: isPositive,
                comment: controller.text,
              );
              // Aquí deberías guardar la sugerencia en tu backend o estado global
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

  /// Muestra un diálogo para asignar positivo/negativo directo
  void _showDirectAssignDialog(BuildContext context, bool isPositive) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Asignar ${isPositive ? "positivo" : "negativo"}"),
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
              try {
                team.assignDirect(
                  requester: currentUser,
                  target: member,
                  isPositive: isPositive,
                  comment: controller.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "${isPositive ? "Positivo" : "Negativo"} asignado a ${member.name}",
                    ),
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Asignar"),
          ),
        ],
      ),
    );
  }

  /// Hace admin a un miembro
  void _makeAdmin(BuildContext context) {
    try {
      team.addAdmin(currentUser, member);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${member.name} ahora es administrador")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  /// Muestra el historial de un miembro
  void _showHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Historial de ${member.name}"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: member.history
                .map(
                  (h) => ListTile(
                    title: Text(h.description),
                    subtitle: Text(h.date.toString()),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }
}
