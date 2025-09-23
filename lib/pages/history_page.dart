import 'package:flutter/material.dart';
import 'package:up_down/widgets/app_drawer.dart';
import '../models/models.dart';
import '../widgets/history_card.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Recuperamos el miembro pasado como argumento
    final member = ModalRoute.of(context)!.settings.arguments as Member;

    // Ordenamos el historial por fecha descendente (más nuevo primero)
    final sortedHistory = List.of(member.history)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: Text("Historial de ${member.name}")),
      drawer: const AppDrawer(),
      body: ListView.builder(
        itemCount: sortedHistory.length,
        itemBuilder: (context, index) {
          final item = sortedHistory[index];
          return HistoryCard(item: item);
        },
      ),
    );
  }
}
