import 'package:flutter/material.dart';
import '../models/models.dart';

/// Widget reutilizable para mostrar un ítem del historial de un miembro.
/// Incluye descripción, fecha y un icono según sea positivo, negativo o cambio de estado.
class HistoryCard extends StatelessWidget {
  final HistoryItem item; // el registro del historial a mostrar

  const HistoryCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // Elegimos un icono y color según el contenido del historial
    IconData icon;
    Color color;

    if (item.description.contains("+1")) {
      icon = Icons.thumb_up;
      color = Colors.green;
    } else if (item.description.contains("-1")) {
      icon = Icons.thumb_down;
      color = Colors.red;
    } else if (item.description.contains("dado de baja")) {
      icon = Icons.person_off;
      color = Colors.orange;
    } else if (item.description.contains("reactivado")) {
      icon = Icons.person_add;
      color = Colors.blue;
    } else {
      icon = Icons.info;
      color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: Icon(icon, color: color), // icono según el tipo de acción
        title: Text(item.description), // la acción realizada
        subtitle: Text(
          // mostramos fecha y hora en formato legible
          "${item.date.day}/${item.date.month}/${item.date.year} "
          "${item.date.hour}:${item.date.minute.toString().padLeft(2, '0')}",
        ),
      ),
    );
  }
}
