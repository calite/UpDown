import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/pages/home_page.dart';
import 'package:up_down/services/app_data_service.dart';
import 'package:up_down/services/auth_service.dart';

class TeamDetailPageWrapper extends StatefulWidget {
  const TeamDetailPageWrapper({super.key});

  @override
  State<TeamDetailPageWrapper> createState() => _TeamDetailPageWrapperState();
}

class _TeamDetailPageWrapperState extends State<TeamDetailPageWrapper> {
  bool _initialized = false;
  bool _loading = true;
  String? _error;
  Team? _team;
  Member? _currentUser;
  CurrentUserProfile? _currentProfile;
  List<Suggestion> _suggestions = [];
  List<Team> _allTeams = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    _resolveContext();
  }

  Future<void> _resolveContext() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
          {};
      final argTeam = args['team'] as Team?;
      if (argTeam != null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _team = argTeam;
          _currentUser =
              args['currentUser'] as Member? ??
              Member(name: 'Invitado', role: UserRole.user);
          _currentProfile = args['currentProfile'] as CurrentUserProfile?;
          _suggestions = args['suggestions'] as List<Suggestion>? ?? [];
          _allTeams = args['allTeams'] as List<Team>? ?? [];
          _loading = false;
        });
        return;
      }

      final profile = await AuthService.instance.getCurrentUserProfile();
      final snapshot = await AppDataService.instance.loadOrSeed(
        canSeed: profile.member.role == UserRole.admin,
      );
      Team? team;
      final linkedTeamId = profile.linkedTeamId?.trim();
      if (linkedTeamId != null && linkedTeamId.isNotEmpty) {
        team = snapshot.teams.where((t) => t.id == linkedTeamId).firstOrNull;
      }
      team ??= snapshot.teams.firstOrNull;

      if (!mounted) {
        return;
      }
      setState(() {
        _team = team;
        _currentUser = profile.member;
        _currentProfile = profile;
        _suggestions = snapshot.suggestions;
        _allTeams = snapshot.teams;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Equipo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _resolveContext,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_team == null || _currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Equipo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudo determinar el equipo a mostrar.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/teams'),
                  child: const Text('Ir a equipos'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return HomePage(
      team: _team!,
      currentUser: _currentUser!,
      currentProfile: _currentProfile,
      suggestions: _suggestions,
      allTeams: _allTeams,
    );
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
