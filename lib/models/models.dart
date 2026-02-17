import 'dart:math';

import 'package:up_down/config/app_config.dart';

enum UserRole { admin, user }

class _Id {
  static final Random _random = Random();

  static String next() {
    final now = DateTime.now().microsecondsSinceEpoch;
    // En web, los desplazamientos de 32 bits pueden desbordar a 0.
    final r = _random.nextInt(0x7fffffff);
    return '${now}_$r';
  }
}

class Member {
  final String id;
  String name;
  String lastName;
  int positives;
  int negatives;
  bool isActive;
  List<HistoryItem> history;
  UserRole role;

  Member({
    String? id,
    required this.name,
    this.lastName = '',
    this.positives = 0,
    this.negatives = 0,
    this.isActive = true,
    List<HistoryItem>? history,
    this.role = UserRole.user,
  })  : id = id ?? _Id.next(),
        history = history ?? [];

  int get totalScore {
    return (positives * AppConfig.positiveValue) +
        (negatives * AppConfig.negativeValue);
  }

  String get displayName {
    final ln = lastName.trim();
    if (ln.isEmpty) {
      return name;
    }
    return '$name $ln';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lastName': lastName,
      'positives': positives,
      'negatives': negatives,
      'isActive': isActive,
      'role': role.name,
      'history': history.map((item) => item.toMap()).toList(),
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    final historyData = (map['history'] as List<dynamic>? ?? []);
    final rawName = map['name'] as String? ?? 'Sin nombre';
    final rawLastName = map['lastName'] as String?;
    final resolvedLastName = rawLastName ?? _extractLastName(rawName);
    final resolvedName = rawLastName == null ? _extractFirstName(rawName) : rawName;
    return Member(
      id: map['id'] as String?,
      name: resolvedName,
      lastName: resolvedLastName,
      positives: (map['positives'] as num?)?.toInt() ?? 0,
      negatives: (map['negatives'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      role: (map['role'] as String?) == UserRole.admin.name
          ? UserRole.admin
          : UserRole.user,
      history: historyData
          .whereType<Map>()
          .map((item) => HistoryItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class TeamSettings {
  bool allowExternalSuggestions;

  TeamSettings({this.allowExternalSuggestions = false});

  Map<String, dynamic> toMap() {
    return {'allowExternalSuggestions': allowExternalSuggestions};
  }

  factory TeamSettings.fromMap(Map<String, dynamic> map) {
    return TeamSettings(
      allowExternalSuggestions: map['allowExternalSuggestions'] as bool? ?? false,
    );
  }
}

class Team {
  final String id;
  final String name;
  final List<Member> members;
  bool isActive;
  TeamSettings settings;
  final List<HistoryItem> teamHistory = [];
  final List<Suggestion> pendingSuggestions = [];

  Team({
    String? id,
    required this.name,
    required this.members,
    this.isActive = true,
    TeamSettings? settings,
    List<HistoryItem>? teamHistory,
  })  : id = id ?? _Id.next(),
        settings = settings ?? TeamSettings() {
    if (teamHistory != null) {
      this.teamHistory.addAll(teamHistory);
    }
  }

  List<Member> get admins =>
      members.where((m) => m.role == UserRole.admin).toList();

  void addAdmin(Member requester, Member newAdmin) {
    if (requester.role != UserRole.admin) {
      throw Exception('Solo un administrador puede asignar nuevos admins.');
    }
    newAdmin.role = UserRole.admin;
  }

  void addSuggestion(Suggestion suggestion) {
    pendingSuggestions.add(suggestion);
  }

  void approveSuggestion(Member requester, Suggestion suggestion) {
    if (requester.role != UserRole.admin) {
      throw Exception('Solo un administrador puede aprobar sugerencias.');
    }
    if (suggestion.approved || suggestion.rejected) {
      throw Exception('La sugerencia ya fue gestionada.');
    }

    suggestion.approved = true;

    if (suggestion.isPositive) {
      suggestion.to.positives++;
    } else {
      suggestion.to.negatives++;
    }

    final historyItem = suggestion.toHistoryItem();
    suggestion.to.history.add(historyItem);

    teamHistory.add(
      HistoryItem(
        'APROBADA: ${historyItem.description} (por ${requester.displayName})',
        DateTime.now(),
      ),
    );

    pendingSuggestions.remove(suggestion);
  }

  void rejectSuggestion(
    Member requester,
    Suggestion suggestion, {
    String? comment,
  }) {
    if (requester.role != UserRole.admin) {
      throw Exception('Solo un administrador puede rechazar sugerencias.');
    }
    if (suggestion.approved || suggestion.rejected) {
      throw Exception('La sugerencia ya fue gestionada.');
    }

    suggestion.rejected = true;
    suggestion.rejectionComment = comment;

    final description =
        'SUGERENCIA RECHAZADA: ${suggestion.from.displayName} sugirio un '
        '${suggestion.isPositive ? 'positivo' : 'negativo'} para '
        '${suggestion.to.displayName}. Motivo: ${comment ?? 'no especificado'}';

    suggestion.to.history.add(HistoryItem(description, DateTime.now()));

    teamHistory.add(
      HistoryItem(
        '$description (rechazada por ${requester.displayName})',
        DateTime.now(),
      ),
    );

    pendingSuggestions.remove(suggestion);
  }

  void assignDirect({
    required Member requester,
    required Member target,
    required bool isPositive,
    required String comment,
  }) {
    if (requester.role != UserRole.admin) {
      throw Exception(
        'Solo un administrador puede asignar positivos/negativos.',
      );
    }

    if (isPositive) {
      target.positives++;
    } else {
      target.negatives++;
    }

    final description =
        '${isPositive ? 'positivo' : 'negativo'} asignado por ${requester.displayName} '
        'a ${target.displayName} ($comment)';

    target.history.add(HistoryItem(description, DateTime.now()));

    teamHistory.add(
      HistoryItem('ASIGNACION DIRECTA: $description', DateTime.now()),
    );
  }

  Map<String, dynamic> toMap({bool includeMembers = true}) {
    return {
      'id': id,
      'name': name,
      'isActive': isActive,
      'settings': settings.toMap(),
      'teamHistory': teamHistory.map((item) => item.toMap()).toList(),
      if (includeMembers) 'members': members.map((member) => member.toMap()).toList(),
    };
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    final membersData = (map['members'] as List<dynamic>? ?? []);
    final historyData = (map['teamHistory'] as List<dynamic>? ?? []);

    return Team(
      id: map['id'] as String?,
      name: map['name'] as String? ?? 'Equipo sin nombre',
      members: membersData
          .whereType<Map>()
          .map((item) => Member.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      isActive: map['isActive'] as bool? ?? true,
      settings: TeamSettings.fromMap(
        map['settings'] is Map
            ? Map<String, dynamic>.from(map['settings'] as Map)
            : const {},
      ),
      teamHistory: historyData
          .whereType<Map>()
          .map((item) => HistoryItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class HistoryItem {
  final String description;
  final DateTime date;

  HistoryItem(this.description, this.date);

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'date': date.toIso8601String(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      map['description'] as String? ?? '',
      DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class Suggestion {
  final String id;
  final Member from;
  final Member to;
  final bool isPositive;
  final String comment;
  bool approved;
  bool rejected;
  String? rejectionComment;
  DateTime date;
  String? teamId;
  String? teamName;

  Suggestion({
    String? id,
    required this.from,
    required this.to,
    required this.isPositive,
    required this.comment,
    this.approved = false,
    this.rejected = false,
    this.rejectionComment,
    DateTime? date,
    this.teamId,
    this.teamName,
  })  : id = id ?? _Id.next(),
        date = date ?? DateTime.now();

  String get description =>
      '${from.displayName} sugirio un ${isPositive ? 'positivo' : 'negativo'} '
      'para ${to.displayName}: "$comment"';

  HistoryItem toHistoryItem() {
    final action = isPositive ? 'positivo' : 'negativo';
    return HistoryItem('$action para ${to.displayName} ($comment)', date);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teamId': teamId,
      'teamName': teamName,
      'fromMemberId': from.id,
      'fromName': from.name,
      'toMemberId': to.id,
      'toName': to.name,
      'isPositive': isPositive,
      'comment': comment,
      'approved': approved,
      'rejected': rejected,
      'rejectionComment': rejectionComment,
      'date': date.toIso8601String(),
    };
  }

  static Suggestion fromMap(
    Map<String, dynamic> map, {
    required Map<String, Team> teamsById,
  }) {
    final teamId = map['teamId'] as String?;
    final team = teamId == null ? null : teamsById[teamId];

    final fromId = map['fromMemberId'] as String?;
    final toId = map['toMemberId'] as String?;

    final fromMember = _memberById(team, fromId) ??
        Member(
          id: fromId,
          name: map['fromName'] as String? ?? 'Usuario',
        );

    final toMember = _memberById(team, toId) ??
        Member(
          id: toId,
          name: map['toName'] as String? ?? 'Usuario',
        );

    return Suggestion(
      id: map['id'] as String?,
      from: fromMember,
      to: toMember,
      isPositive: map['isPositive'] as bool? ?? true,
      comment: map['comment'] as String? ?? '',
      approved: map['approved'] as bool? ?? false,
      rejected: map['rejected'] as bool? ?? false,
      rejectionComment: map['rejectionComment'] as String?,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      teamId: teamId,
      teamName: map['teamName'] as String?,
    );
  }

  static Member? _memberById(Team? team, String? memberId) {
    if (team == null || memberId == null) {
      return null;
    }
    return team.members.where((m) => m.id == memberId).firstOrNull;
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

String _extractFirstName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) {
    return 'Sin nombre';
  }
  return parts.first;
}

String _extractLastName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length < 2) {
    return '';
  }
  return parts.sublist(1).join(' ');
}
