import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/services/app_data_service.dart';
import 'package:up_down/services/auth_service.dart';
import 'package:up_down/widgets/base_scaffold.dart';

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  Member? _currentUser;
  List<Team> _allTeams = [];
  List<Suggestion> _suggestions = [];
  bool _loading = true;
  String? _error;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final currentUser = await AuthService.instance.getCurrentMemberProfile();
      final snapshot = await AppDataService.instance.loadOrSeed(
        canSeed: currentUser.role == UserRole.admin,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = currentUser;
        _allTeams = snapshot.teams;
        _suggestions = snapshot.suggestions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _persistState() {
    return AppDataService.instance.saveState(_allTeams, _suggestions);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'No se pudo cargar la informacion.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BaseScaffold(
      title: 'Mis equipos',
      args: {
        'currentUser': _currentUser,
        'teams': _allTeams,
        'suggestions': _suggestions,
      },
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          itemCount: _allTeams.length,
          itemBuilder: (context, index) {
            final team = _allTeams[index];
            return ListTile(
              leading: const Icon(Icons.group),
              title: Text(team.name),
              subtitle: Text('${team.members.length} miembros'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/team-detail',
                  arguments: {
                    'team': team,
                    'currentUser': _currentUser,
                    'suggestions': _suggestions,
                    'allTeams': _allTeams,
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: _currentUser!.role == UserRole.admin
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () => _showAddTeamDialog(context),
            )
          : null,
    );
  }

  void _showAddTeamDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Crear equipo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nombre del equipo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                return;
              }
              setState(() {
                _allTeams.add(Team(name: name, members: []));
              });
              await _persistState();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
