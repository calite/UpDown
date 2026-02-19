import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/services/app_data_service.dart';
import 'package:up_down/services/auth_service.dart';
import 'package:up_down/widgets/app_drawer.dart';
import 'package:up_down/widgets/success_snackbar.dart';

class HistoryPage extends StatefulWidget {
  final Member? member;
  final Map<String, dynamic>? args;

  const HistoryPage({super.key, this.member, this.args});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _loading = true;
  String? _error;
  Member? _member;
  String? _teamId;
  Member? _currentUser;
  CurrentUserProfile? _currentProfile;
  List<Team> _teams = [];
  List<Suggestion> _suggestions = [];
  Map<String, dynamic> _resolvedArgs = const {};
  String? _selectedActorId;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _resolvedArgs = widget.args ?? const {};
    _resolveContext();
  }

  Future<void> _resolveContext() async {
    try {
      final args = widget.args ?? const <String, dynamic>{};
      _teamId = args['teamId'] as String?;
      _currentUser = args['currentUser'] as Member?;
      _currentProfile = args['currentProfile'] as CurrentUserProfile?;
      _teams = args['teams'] as List<Team>? ?? [];
      _suggestions = args['suggestions'] as List<Suggestion>? ?? [];
      _member ??= args['member'] as Member?;

      if (_member != null &&
          _currentUser != null &&
          _currentProfile != null &&
          _teams.isNotEmpty) {
        if (!mounted) {
          return;
        }
        setState(() => _loading = false);
        return;
      }

      final profile = await AuthService.instance.getCurrentUserProfile();
      final snapshot = await AppDataService.instance.loadOrSeed(
        canSeed: profile.member.role == UserRole.admin,
      );

      _currentUser ??= profile.member;
      _currentProfile ??= profile;
      _teams = _teams.isNotEmpty ? _teams : snapshot.teams;
      _suggestions = _suggestions.isNotEmpty
          ? _suggestions
          : snapshot.suggestions;

      if (_member == null) {
        final linkedTeamId = profile.linkedTeamId?.trim();
        final linkedMemberId = profile.linkedMemberId?.trim();
        if (linkedTeamId != null &&
            linkedTeamId.isNotEmpty &&
            linkedMemberId != null &&
            linkedMemberId.isNotEmpty) {
          _teamId ??= linkedTeamId;
          final team = _teams.where((t) => t.id == linkedTeamId).firstOrNull;
          _member = team?.members
              .where((m) => m.id == linkedMemberId)
              .firstOrNull;
        }
      }

      _resolvedArgs = {
        ..._resolvedArgs,
        'currentUser': _currentUser,
        'currentProfile': _currentProfile,
        'teams': _teams,
        'suggestions': _suggestions,
      };

      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
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

  Future<void> _runAction(Future<void> Function() action) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.transparent,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await action();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  int _scoreDeltaFromDescription(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('sugerencia rechazada')) {
      return 0;
    }
    if (desc.contains('positivo')) {
      return 1;
    }
    if (desc.contains('negativo')) {
      return -1;
    }
    return 0;
  }

  String? _extractActorName(String description) {
    final rx = RegExp(
      r'^(?:APROBADA:\s+|ASIGNACION DIRECTA:\s+)?(.*?)\s+le dio un\s+(positivo|negativo)\s+a\s+(.+?):',
    );
    final modernMatch = rx.firstMatch(description);
    if (modernMatch != null) {
      return (modernMatch.group(1) ?? '').trim();
    }

    final lower = description.toLowerCase();
    const directMarker = ' asignado por ';
    final directIdx = lower.indexOf(directMarker);
    if (directIdx >= 0) {
      final after = description.substring(directIdx + directMarker.length);
      final end = after.toLowerCase().indexOf(' a ');
      return (end >= 0 ? after.substring(0, end) : after).trim();
    }

    const approvedMarker = '(aprobada por ';
    final approvedIdx = lower.lastIndexOf(approvedMarker);
    if (approvedIdx >= 0) {
      final after = description.substring(approvedIdx + approvedMarker.length);
      final end = after.indexOf(')');
      return (end >= 0 ? after.substring(0, end) : after).trim();
    }
    const legacyApprovedMarker = '(por ';
    final legacyApprovedIdx = lower.lastIndexOf(legacyApprovedMarker);
    if (legacyApprovedIdx >= 0) {
      final after = description.substring(
        legacyApprovedIdx + legacyApprovedMarker.length,
      );
      final end = after.indexOf(')');
      return (end >= 0 ? after.substring(0, end) : after).trim();
    }

    return null;
  }

  List<HistoryItem> _applyActorFilter(
    List<HistoryItem> items,
    List<Member> teamMembers,
  ) {
    if (_selectedActorId == null || _selectedActorId!.isEmpty) {
      return items;
    }
    final actor = teamMembers
        .where((m) => m.id == _selectedActorId)
        .firstOrNull;
    if (actor == null) {
      return items;
    }
    final actorName = actor.displayName.toLowerCase();
    return items.where((item) {
      if (_scoreDeltaFromDescription(item.description) == 0) {
        return false;
      }
      final entryActor = _extractActorName(item.description)?.toLowerCase();
      return entryActor == actorName;
    }).toList();
  }

  Team? _resolveMemberTeam() {
    if (_member == null) {
      return null;
    }
    if (_teamId != null && _teamId!.isNotEmpty) {
      final team = _teams.where((t) => t.id == _teamId).firstOrNull;
      if (team != null) {
        return team;
      }
    }
    return _teams
        .where((t) => t.members.any((m) => m.id == _member!.id))
        .firstOrNull;
  }

  Future<void> _deleteMemberScoreHistoryItem(HistoryItem item) async {
    if (_member == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text(
          'Se eliminara este positivo/negativo del historial del integrante. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final delta = _scoreDeltaFromDescription(item.description);
    final team = _resolveMemberTeam();
    if (team == null) {
      return;
    }

    await _runAction(() async {
      setState(() {
        _member!.history.remove(item);
        if (delta > 0 && _member!.positives > 0) {
          _member!.positives--;
        }
        if (delta < 0 && _member!.negatives > 0) {
          _member!.negatives--;
        }
        final mirror = team.teamHistory
            .where(
              (h) =>
                  h.description.contains(item.description) &&
                  _scoreDeltaFromDescription(h.description) == delta,
            )
            .firstOrNull;
        if (mirror != null) {
          team.teamHistory.remove(mirror);
        }
      });
      await AppDataService.instance.saveState(_teams, _suggestions);
    });

    if (!mounted) {
      return;
    }
    showSuccessSnackBar(context, 'Registro eliminado');
  }

  String _likerUid() {
    final profileUid = _currentProfile?.uid.trim();
    if (profileUid != null && profileUid.isNotEmpty) {
      return profileUid;
    }
    return _currentUser?.id ?? '';
  }

  String _likerName() {
    final name = _currentUser?.displayName.trim() ?? '';
    return name.isEmpty ? 'Usuario' : name;
  }

  Future<void> _showPlusOneDialog(HistoryItem item) async {
    final uid = _likerUid();
    if (uid.isEmpty) {
      return;
    }
    final displayName = _likerName();
    final hasPlusOne = item.plusOnes.any((p) => p.userUid == uid);

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reacciones +1'),
        content: SizedBox(
          width: 420,
          child: item.plusOnes.isEmpty
              ? const Text('Aun no hay reacciones en este registro.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: item.plusOnes.length,
                  itemBuilder: (context, index) {
                    final p = item.plusOnes[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.thumb_up, color: Colors.green),
                      title: Text(p.displayName),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _runAction(() async {
                setState(() {
                  final index = item.plusOnes.indexWhere(
                    (p) => p.userUid == uid,
                  );
                  if (index >= 0) {
                    item.plusOnes.removeAt(index);
                  } else {
                    item.plusOnes.add(
                      HistoryPlusOne(userUid: uid, displayName: displayName),
                    );
                  }
                });
                await AppDataService.instance.saveState(_teams, _suggestions);
              });
            },
            icon: Icon(
              hasPlusOne
                  ? Icons.remove_circle_outline
                  : Icons.add_circle_outline,
            ),
            label: Text(hasPlusOne ? 'Quitar +1' : 'Dar +1'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historial')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _resolveContext();
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_member == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historial')),
        body: const Center(child: Text('No se ha especificado un miembro')),
      );
    }

    final historyItems = List<HistoryItem>.from(_member!.history)
      ..sort((a, b) => b.date.compareTo(a.date));
    final memberTeam = _resolveMemberTeam();
    final teamMembers = memberTeam == null
        ? const <Member>[]
        : (List<Member>.from(memberTeam.members)..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          ));
    final filteredItems = _applyActorFilter(historyItems, teamMembers);
    final canDeleteScores = _currentUser?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text('Historial de ${_member!.name}'),
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
      endDrawer: AppDrawer(args: _resolvedArgs),
      body: Column(
        children: [
          if (teamMembers.isNotEmpty)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedActorId,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar positivos/negativos por integrante',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ...teamMembers.map(
                        (member) => DropdownMenuItem<String?>(
                          value: member.id,
                          child: Text(member.displayName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedActorId = value);
                    },
                  ),
                ),
              ),
            ),
          Expanded(
            child: filteredItems.isEmpty
                ? const Center(child: Text('No hay historial de este miembro'))
                : ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final scoreDelta = _scoreDeltaFromDescription(
                        item.description,
                      );
                      final isScore = scoreDelta != 0;
                      final isPositive = scoreDelta > 0;
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            color: isScore
                                ? (isPositive
                                      ? Colors.green.shade50
                                      : Colors.red.shade50)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isScore
                                    ? (isPositive
                                          ? Colors.green.shade200
                                          : Colors.red.shade200)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    item.description.contains('rechazada')
                                        ? Icons.close
                                        : item.description.contains('positivo')
                                        ? Icons.thumb_up
                                        : item.description.contains('negativo')
                                        ? Icons.thumb_down
                                        : Icons.info,
                                    color:
                                        item.description.contains('rechazada')
                                        ? Colors.red
                                        : item.description.contains('positivo')
                                        ? Colors.green
                                        : item.description.contains('negativo')
                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.description,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${item.date.day}/${item.date.month}/${item.date.year} '
                                          '${item.date.hour.toString().padLeft(2, '0')}:${item.date.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () =>
                                            _showPlusOneDialog(item),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          shape: const StadiumBorder(),
                                          side: BorderSide(
                                            color: Colors.blue.shade200,
                                          ),
                                          backgroundColor: Colors.blue.shade50,
                                        ),
                                        child: Text(
                                          '+ ${item.plusOnes.length}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (canDeleteScores && isScore)
                                        IconButton(
                                          tooltip: 'Eliminar positivo/negativo',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _deleteMemberScoreHistoryItem(
                                                item,
                                              ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
