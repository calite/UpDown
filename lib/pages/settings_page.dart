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
  late TextEditingController _nameController;
  late TextEditingController _lastNameController;
  late TextEditingController _aliasController;
  bool _loadingProfile = false;

  Member? get _currentUser => widget.args['currentUser'] as Member?;
  CurrentUserProfile? get _currentProfile =>
      widget.args['currentProfile'] as CurrentUserProfile?;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _currentUser?.name ?? '');
    _lastNameController = TextEditingController(
      text: _currentUser?.lastName ?? '',
    );
    _aliasController = TextEditingController(text: _currentUser?.alias ?? '');
    if (_currentUser == null) {
      _loadCurrentProfileFallback();
    }
  }

  Future<void> _loadCurrentProfileFallback() async {
    setState(() => _loadingProfile = true);
    try {
      final profile = await AuthService.instance.getCurrentUserProfile();
      if (!mounted) {
        return;
      }
      _nameController.text = profile.member.name;
      _lastNameController.text = profile.member.lastName;
      _aliasController.text = profile.member.alias;
      widget.args['currentUser'] = profile.member;
      widget.args['currentProfile'] = profile;
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _aliasController.dispose();
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
      final user = _currentUser;
      if (user != null) {
        final newName = _nameController.text.trim();
        final newLastName = _lastNameController.text.trim();
        final newAlias = _aliasController.text.trim();
        if (newName.isNotEmpty && newLastName.isNotEmpty) {
          await AuthService.instance.updateCurrentUserProfile(
            name: newName,
            lastName: newLastName,
            alias: newAlias,
          );
          user.name = newName;
          user.lastName = newLastName;
          user.alias = newAlias;
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
      await showErrorDialog(context, title: ErrorTitles.saveSettings, error: e);
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
      endDrawer: AppDrawer(
        args: widget.args.isNotEmpty ? widget.args : const {},
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: _loadingProfile
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Perfil',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _lastNameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Apellido'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _aliasController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Alias'),
                    ),
                    const SizedBox(height: 30),
                    const SizedBox(height: 24),
                    const Text(
                      'Mostrar secciones de estadisticas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Totales globales'),
                      value: AppConfig.showGlobalStats,
                      onChanged: (value) =>
                          setState(() => AppConfig.showGlobalStats = value),
                    ),
                    SwitchListTile(
                      title: const Text('Comparacion entre equipos'),
                      value: AppConfig.showTeamStats,
                      onChanged: (value) =>
                          setState(() => AppConfig.showTeamStats = value),
                    ),
                    SwitchListTile(
                      title: const Text('Detalle por integrantes'),
                      value: AppConfig.showMemberStats,
                      onChanged: (value) =>
                          setState(() => AppConfig.showMemberStats = value),
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
