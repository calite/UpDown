import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/services/app_data_service.dart';
import 'package:up_down/services/auth_service.dart';
import 'package:up_down/widgets/app_drawer.dart';
import 'package:up_down/widgets/success_snackbar.dart';

class HistoryTab extends StatefulWidget {
  final Team team;
  final Member currentUser;
  final CurrentUserProfile? currentProfile;
  final List<Team> allTeams;
  final List<Suggestion> suggestions;

  const HistoryTab({
    super.key,
    required this.team,
    required this.currentUser,
    required this.currentProfile,
    required this.allTeams,
    required this.suggestions,
  });

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String? _selectedActorId;

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

  String? _extractTargetName(String description) {
    final rx = RegExp(
      r'^(?:APROBADA:\s+|ASIGNACION DIRECTA:\s+)?(.*?)\s+le dio un\s+(positivo|negativo)\s+a\s+(.+?):',
    );
    final modernMatch = rx.firstMatch(description);
    if (modernMatch != null) {
      return (modernMatch.group(3) ?? '').trim();
    }

    if (description.contains('positivo para ') ||
        description.contains('negativo para ')) {
      final marker = description.contains('positivo para ')
          ? 'positivo para '
          : 'negativo para ';
      final start = description.indexOf(marker);
      if (start >= 0) {
        final raw = description.substring(start + marker.length);
        final end = raw.indexOf(' (');
        return (end >= 0 ? raw.substring(0, end) : raw).trim();
      }
    }
    if (description.contains(' asignado por ') && description.contains(' a ')) {
      final start = description.lastIndexOf(' a ');
      if (start >= 0) {
        final raw = description.substring(start + 3);
        final end = raw.indexOf(' (');
        return (end >= 0 ? raw.substring(0, end) : raw).trim();
      }
    }
    return null;
  }

  Future<void> _deleteScoreFromTeamHistory(HistoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text(
          'Se eliminara este positivo/negativo del historico del equipo. Continuar?',
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
    final targetName = _extractTargetName(item.description)?.toLowerCase();

    await _runAction(() async {
      setState(() {
        widget.team.teamHistory.remove(item);
        if (delta != 0 && targetName != null && targetName.isNotEmpty) {
          final target = widget.team.members
              .where((m) => m.displayName.toLowerCase() == targetName)
              .firstOrNull;
          if (target != null) {
            if (delta > 0 && target.positives > 0) {
              target.positives--;
            }
            if (delta < 0 && target.negatives > 0) {
              target.negatives--;
            }
          }
        }
      });
      await AppDataService.instance.saveState(
        widget.allTeams,
        widget.suggestions,
      );
    });

    if (!mounted) {
      return;
    }
    showSuccessSnackBar(context, 'Registro eliminado');
  }

  String _likerUid() {
    final profileUid = widget.currentProfile?.uid.trim();
    if (profileUid != null && profileUid.isNotEmpty) {
      return profileUid;
    }
    return widget.currentUser.id;
  }

  String _likerName() {
    final name = widget.currentUser.displayName.trim();
    return name.isEmpty ? 'Usuario' : name;
  }

  Future<void> _showPlusOneDialog(HistoryItem item) async {
    final uid = _likerUid();
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
                await AppDataService.instance.saveState(
                  widget.allTeams,
                  widget.suggestions,
                );
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
    final historyItems = List<HistoryItem>.from(widget.team.teamHistory)
      ..sort((a, b) => b.date.compareTo(a.date));
    final teamMembers = List<Member>.from(widget.team.members)
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    final filteredItems = _applyActorFilter(historyItems, teamMembers);
    final canDeleteScores = widget.currentUser.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Historial de ${widget.team.name}'),
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
        args: {
          'currentUser': widget.currentUser,
          'currentProfile': widget.currentProfile,
          'teams': widget.allTeams,
          'suggestions': widget.suggestions,
        },
      ),
      body: Column(
        children: [
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
                ? const Center(child: Text('No hay historial del equipo'))
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
                                              _deleteScoreFromTeamHistory(item),
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
