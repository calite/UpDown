import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../config/app_config.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> args;

  const SettingsPage({super.key, required this.args});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int positiveValue;
  late int negativeValue;

  @override
  void initState() {
    super.initState();
    positiveValue = AppConfig.positiveValue;
    negativeValue = AppConfig.negativeValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("⚙️ Configuración")),
      endDrawer: AppDrawer(
        args: widget.args.isNotEmpty ? widget.args : const {},
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            "Sistema de puntuación",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text("Valor de cada positivo (+): "),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => setState(() => positiveValue--),
              ),
              Text("$positiveValue"),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => positiveValue++),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text("Valor de cada negativo (-): "),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => setState(() => negativeValue--),
              ),
              Text("$negativeValue"),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => negativeValue++),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            "Mostrar secciones de estadísticas",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text("Totales globales"),
            value: AppConfig.showGlobalStats,
            onChanged: (value) =>
                setState(() => AppConfig.showGlobalStats = value),
          ),
          SwitchListTile(
            title: const Text("Comparación entre equipos"),
            value: AppConfig.showTeamStats,
            onChanged: (value) =>
                setState(() => AppConfig.showTeamStats = value),
          ),
          SwitchListTile(
            title: const Text("Detalle por integrantes"),
            value: AppConfig.showMemberStats,
            onChanged: (value) =>
                setState(() => AppConfig.showMemberStats = value),
          ),
          const SizedBox(height: 30),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Guardar configuración"),
              onPressed: () {
                AppConfig.positiveValue = positiveValue;
                AppConfig.negativeValue = negativeValue;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Configuración guardada ✅")),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
