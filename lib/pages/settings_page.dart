import 'package:flutter/material.dart';
import 'package:up_down/config/app_config.dart';
import 'package:up_down/config/error_titles.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/services/auth_service.dart';
import 'package:up_down/widgets/app_drawer.dart';
import 'package:up_down/widgets/error_dialog.dart';
import 'package:up_down/widgets/success_snackbar.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> args;

  const SettingsPage({super.key, required this.args});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int positiveValue;
  late int negativeValue;
  late TextEditingController _nameController;
  late TextEditingController _lastNameController;

  Member? get _currentUser => widget.args['currentUser'] as Member?;

  @override
  void initState() {
    super.initState();
    positiveValue = AppConfig.positiveValue;
    negativeValue = AppConfig.negativeValue;
    _nameController = TextEditingController(text: _currentUser?.name ?? '');
    _lastNameController = TextEditingController(text: _currentUser?.lastName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.transparent,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      AppConfig.positiveValue = positiveValue;
      AppConfig.negativeValue = negativeValue;

      final user = _currentUser;
      if (user != null) {
        final newName = _nameController.text.trim();
        final newLastName = _lastNameController.text.trim();
        if (newName.isNotEmpty && newLastName.isNotEmpty) {
          await AuthService.instance.updateCurrentUserProfile(
            name: newName,
            lastName: newLastName,
          );
          user.name = newName;
          user.lastName = newLastName;
        }
      }

      if (!mounted) {
        return;
      }
      showSuccessSnackBar(context, 'Configuracion guardada');
    } catch (e) {
      if (!mounted) {
        return;
      }
      await showErrorDialog(
        context,
        title: ErrorTitles.saveSettings,
        error: e,
      );
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: AppDrawer(args: widget.args.isNotEmpty ? widget.args : const {}),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Perfil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Apellidos'),
              ),
              const SizedBox(height: 30),
              const Text(
                'Sistema de puntuacion',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Valor de cada positivo (+): '),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => setState(() => positiveValue--),
                  ),
                  Text('$positiveValue'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => positiveValue++),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Valor de cada negativo (-): '),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => setState(() => negativeValue--),
                  ),
                  Text('$negativeValue'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => negativeValue++),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                'Mostrar secciones de estadisticas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Totales globales'),
                value: AppConfig.showGlobalStats,
                onChanged: (value) => setState(() => AppConfig.showGlobalStats = value),
              ),
              SwitchListTile(
                title: const Text('Comparacion entre equipos'),
                value: AppConfig.showTeamStats,
                onChanged: (value) => setState(() => AppConfig.showTeamStats = value),
              ),
              SwitchListTile(
                title: const Text('Detalle por integrantes'),
                value: AppConfig.showMemberStats,
                onChanged: (value) => setState(() => AppConfig.showMemberStats = value),
              ),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar configuracion'),
                  onPressed: _saveSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
