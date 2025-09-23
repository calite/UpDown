import 'package:flutter/material.dart';

/// Un diálogo reutilizable con un campo de texto y botones de acción.
/// Se puede usar para añadir miembros, equipos u otros elementos similares.
class CustomDialog extends StatelessWidget {
  final String title; // título del diálogo
  final String hintText; // texto de ayuda en el input
  final String labelText; // etiqueta del campo de texto
  final String confirmText; // texto del botón de confirmar
  final Function(String value) onConfirm; // acción al confirmar

  const CustomDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.labelText,
    required this.confirmText,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: labelText, hintText: hintText),
      ),
      actions: [
        // Botón de cancelar → simplemente cerramos el diálogo
        TextButton(
          child: const Text("Cancelar"),
          onPressed: () => Navigator.pop(context),
        ),
        // Botón de confirmar → ejecuta la función pasada por parámetro
        ElevatedButton(
          child: Text(confirmText),
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) {
              onConfirm(value); // ejecutamos la acción con el valor
            }
            Navigator.pop(context); // cerramos el diálogo
          },
        ),
      ],
    );
  }
}
