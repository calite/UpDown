import 'package:flutter/material.dart';
import '../models/models.dart';

/// Widget reutilizable que muestra la información de un miembro
/// (nombre, positivos, negativos, estado activo/inactivo)
/// con acciones asociadas (👍 👎 historial dar de baja/reactivar).
class MemberCard extends StatelessWidget {
  final Member member; // miembro a mostrar
  final VoidCallback? onPositive; // acción al dar 👍
  final VoidCallback? onNegative; // acción al dar 👎
  final VoidCallback? onHistory; // acción al abrir historial
  final VoidCallback? onToggleActive; // acción al dar de baja/reactivar

  const MemberCard({
    super.key,
    required this.member,
    this.onPositive,
    this.onNegative,
    this.onHistory,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        // Nombre del miembro (tachado y gris si está inactivo)
        title: Text(
          member.name,
          style: TextStyle(
            color: member.isActive ? Colors.black : Colors.grey,
            decoration: member.isActive ? null : TextDecoration.lineThrough,
          ),
        ),

        // Subtítulo con los puntos y estado
        subtitle: Text(
          "Positivos: ${member.positives} | Negativos: ${member.negatives}" +
              (member.isActive ? "" : " (Inactivo)"),
        ),

        // Zona de botones a la derecha
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón 👍 → solo habilitado si el miembro está activo
            IconButton(
              icon: const Icon(Icons.thumb_up, color: Colors.green),
              onPressed: member.isActive ? onPositive : null,
            ),

            // Botón 👎 → solo habilitado si el miembro está activo
            IconButton(
              icon: const Icon(Icons.thumb_down, color: Colors.red),
              onPressed: member.isActive ? onNegative : null,
            ),

            // Botón 📜 historial → abre la pantalla de historial
            IconButton(
              icon: const Icon(Icons.history, color: Colors.blue),
              onPressed: onHistory,
            ),

            // Botón 👤 baja/reactivar
            IconButton(
              icon: Icon(
                member.isActive ? Icons.person_off : Icons.person_add,
                color: member.isActive ? Colors.orange : Colors.green,
              ),
              onPressed: onToggleActive,
            ),
          ],
        ),
      ),
    );
  }
}
