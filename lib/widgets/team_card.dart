import 'package:flutter/material.dart';
import '../models/models.dart';

class TeamCard extends StatelessWidget {
  final Team team;
  final VoidCallback? onTap;
  final VoidCallback? onToggleActive;

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
        title: Text(
          team.name,
          style: TextStyle(
            color: team.isActive ? Colors.black : Colors.grey,
            decoration: team.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          '${team.members.length} miembros${team.isActive ? ' (Inactivo)' : ''}',
        ),
        onTap: team.isActive ? onTap : null,
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
