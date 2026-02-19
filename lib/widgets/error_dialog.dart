import 'package:flutter/material.dart';
import 'package:up_down/config/error_titles.dart';

Future<void> showErrorDialog(
  BuildContext context, {
  String title = ErrorTitles.generic,
  String? message,
  Object? error,
}) {
  final details = error?.toString().trim();
  final String body;
  if (message?.trim().isNotEmpty == true) {
    body = message!.trim();
  } else if (details != null && details.isNotEmpty) {
    body = details;
  } else {
    body = 'Ha ocurrido un error.';
  }

  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: SelectableText(body)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
