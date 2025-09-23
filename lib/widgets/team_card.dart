import 'package:flutter/material.dart';
import '../models/models.dart';

class TeamCard extends StatelessWidget {
  final Team team; // el equipo a mostrar
  final VoidCallback? onTap; // acción al pulsar la tarjeta (entrar al detalle)
  final VoidCallback? onToggleActive; // acción para dar de baja/reactivar

  const TeamCard({
    super.key,
    required this.team,
    this.onTap,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        // Nombre del equipo (tachado si está inactivo)
        title: Text(
          team.name,
          style: TextStyle(
            color: team.isActive ? Colors.black : Colors.grey,
            decoration: team.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        // Número de miembros + estado
        subtitle: Text(
          "${team.members.length} miembros" +
              (team.isActive ? "" : " (Inactivo)"),
        ),
        // Acción al pulsar la tarjeta completa (solo si está activo)
        onTap: team.isActive ? onTap : null,
        // Botón de acción (dar de baja/reactivar)
        trailing: IconButton(
          icon: Icon(
            team.isActive ? Icons.group_off : Icons.group_add,
            color: team.isActive ? Colors.orange : Colors.green,
          ),
          onPressed: onToggleActive,
        ),
      ),
    );
  }
}
