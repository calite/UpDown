import 'dart:math';

enum UserRole { admin, gestor, user }

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
  String alias;
  String email;
  String emailLower;
  String? authUid;
  int positives;
  int negatives;
  bool isActive;
  List<HistoryItem> history;
  UserRole role;

  Member({
    String? id,
    required this.name,
    this.lastName = '',
    this.alias = '',
    this.email = '',
    this.emailLower = '',
    this.authUid,
    this.positives = 0,
    this.negatives = 0,
    this.isActive = true,
    List<HistoryItem>? history,
    this.role = UserRole.user,
  }) : id = id ?? _Id.next(),
       history = history ?? [];

  int get totalScore {
    return positives - negatives;
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
      'alias': alias,
      'email': email,
      'emailLower': emailLower,
      'authUid': authUid,
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
    final resolvedName = rawLastName == null
        ? _extractFirstName(rawName)
        : rawName;
    return Member(
      id: map['id'] as String?,
      name: resolvedName,
      lastName: resolvedLastName,
      alias: map['alias'] as String? ?? '',
      email: map['email'] as String? ?? '',
      emailLower: map['emailLower'] as String? ?? '',
      authUid: map['authUid'] as String?,
      positives: (map['positives'] as num?)?.toInt() ?? 0,
      negatives: (map['negatives'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      role: (map['role'] as String?) == UserRole.admin.name
          ? UserRole.admin
          : (map['role'] as String?) == UserRole.gestor.name
          ? UserRole.gestor
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
  bool autoApproveJoinRequests;

  TeamSettings({
    this.allowExternalSuggestions = false,
    this.autoApproveJoinRequests = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'allowExternalSuggestions': allowExternalSuggestions,
      'autoApproveJoinRequests': autoApproveJoinRequests,
    };
  }

  factory TeamSettings.fromMap(Map<String, dynamic> map) {
    return TeamSettings(
      allowExternalSuggestions:
          map['allowExternalSuggestions'] as bool? ?? false,
      autoApproveJoinRequests: map['autoApproveJoinRequests'] as bool? ?? false,
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
  }) : id = id ?? _Id.next(),
       settings = settings ?? TeamSettings() {
    if (teamHistory != null) {
      this.teamHistory.addAll(teamHistory);
    }
  }

  List<Member> get admins =>
      members.where((m) => m.role == UserRole.admin).toList();

  bool _canManageSuggestions(Member requester) {
    return requester.role == UserRole.admin ||
        requester.role == UserRole.gestor;
  }

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
    if (!_canManageSuggestions(requester)) {
      throw Exception('Solo admin o gestor puede aprobar sugerencias.');
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
        'APROBADA: ${historyItem.description} (aprobada por ${requester.displayName})',
        DateTime.now(),
      ),
    );

    pendingSuggestions.remove(suggestion);
  }

  void rejectSuggestion(Member requester, Suggestion suggestion) {
    if (!_canManageSuggestions(requester)) {
      throw Exception('Solo admin o gestor puede rechazar sugerencias.');
    }
    if (suggestion.approved || suggestion.rejected) {
      throw Exception('La sugerencia ya fue gestionada.');
    }

    suggestion.rejected = true;
    suggestion.rejectionComment = null;

    final description =
        'SUGERENCIA RECHAZADA: ${suggestion.from.displayName} propuso dar un '
        '${suggestion.isPositive ? 'positivo' : 'negativo'} a '
        '${suggestion.to.displayName}: "${suggestion.comment}"';

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
    if (requester.role != UserRole.admin && requester.role != UserRole.gestor) {
      throw Exception('Solo admin o gestor puede asignar positivos/negativos.');
    }

    if (isPositive) {
      target.positives++;
    } else {
      target.negatives++;
    }

    final description =
        '${requester.displayName} le dio un ${isPositive ? 'positivo' : 'negativo'} '
        'a ${target.displayName}: "$comment"';

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
      if (includeMembers)
        'members': members.map((member) => member.toMap()).toList(),
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
  final List<HistoryPlusOne> plusOnes;

  HistoryItem(this.description, this.date, {List<HistoryPlusOne>? plusOnes})
    : plusOnes = plusOnes ?? [];

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'date': date.toIso8601String(),
      'plusOnes': plusOnes.map((item) => item.toMap()).toList(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    final plusOnesData = (map['plusOnes'] as List<dynamic>? ?? []);
    return HistoryItem(
      map['description'] as String? ?? '',
      DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      plusOnes: plusOnesData
          .whereType<Map>()
          .map(
            (item) => HistoryPlusOne.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class HistoryPlusOne {
  final String userUid;
  final String displayName;

  const HistoryPlusOne({required this.userUid, required this.displayName});

  Map<String, dynamic> toMap() {
    return {'userUid': userUid, 'displayName': displayName};
  }

  factory HistoryPlusOne.fromMap(Map<String, dynamic> map) {
    return HistoryPlusOne(
      userUid: map['userUid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
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
  }) : id = id ?? _Id.next(),
       date = date ?? DateTime.now();

  String get description =>
      '${from.displayName} propuso dar un ${isPositive ? 'positivo' : 'negativo'} '
      'a ${to.displayName}: "$comment"';

  HistoryItem toHistoryItem() {
    final action = isPositive ? 'positivo' : 'negativo';
    return HistoryItem(
      '${from.displayName} le dio un $action a ${to.displayName}: "$comment"',
      date,
    );
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

    final fromMember =
        _memberById(team, fromId) ??
        Member(id: fromId, name: map['fromName'] as String? ?? 'Usuario');

    final toMember =
        _memberById(team, toId) ??
        Member(id: toId, name: map['toName'] as String? ?? 'Usuario');

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

class AppUserRecord {
  final String uid;
  final String email;
  final String name;
  final String lastName;
  final String alias;
  final UserRole role;
  final String? linkedTeamId;
  final String? linkedMemberId;

  const AppUserRecord({
    required this.uid,
    required this.email,
    required this.name,
    required this.lastName,
    required this.alias,
    required this.role,
    required this.linkedTeamId,
    required this.linkedMemberId,
  });

  String get displayName {
    final full = '$name $lastName'.trim();
    return full.isEmpty ? email : full;
  }

  factory AppUserRecord.fromMap(String uid, Map<String, dynamic> map) {
    final roleRaw = map['role'] as String?;
    final role = roleRaw == UserRole.admin.name
        ? UserRole.admin
        : roleRaw == UserRole.gestor.name
        ? UserRole.gestor
        : UserRole.user;
    return AppUserRecord(
      uid: uid,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      alias: map['alias'] as String? ?? '',
      role: role,
      linkedTeamId: map['linkedTeamId'] as String?,
      linkedMemberId: map['linkedMemberId'] as String?,
    );
  }
}

enum LinkRequestStatus { pending, approved, rejected }

class LinkRequest {
  final String id;
  final String userId;
  final String email;
  final String name;
  final String lastName;
  final String teamId;
  final String teamName;
  final String note;
  final DateTime createdAt;
  final LinkRequestStatus status;
  final String? memberId;
  final String? memberName;
  final String? reviewedByUid;
  final String? reviewComment;
  final DateTime? reviewedAt;

  const LinkRequest({
    required this.id,
    required this.userId,
    required this.email,
    required this.name,
    required this.lastName,
    required this.teamId,
    required this.teamName,
    required this.note,
    required this.createdAt,
    required this.status,
    this.memberId,
    this.memberName,
    this.reviewedByUid,
    this.reviewComment,
    this.reviewedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'lastName': lastName,
      'teamId': teamId,
      'teamName': teamName,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'memberId': memberId,
      'memberName': memberName,
      'reviewedByUid': reviewedByUid,
      'reviewComment': reviewComment,
      'reviewedAt': reviewedAt?.toIso8601String(),
    };
  }

  factory LinkRequest.fromMap(String id, Map<String, dynamic> map) {
    LinkRequestStatus status;
    switch (map['status'] as String?) {
      case 'approved':
        status = LinkRequestStatus.approved;
        break;
      case 'rejected':
        status = LinkRequestStatus.rejected;
        break;
      default:
        status = LinkRequestStatus.pending;
    }

    return LinkRequest(
      id: id,
      userId: map['userId'] as String? ?? '',
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      teamId: map['teamId'] as String? ?? '',
      teamName: map['teamName'] as String? ?? '',
      note: map['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      status: status,
      memberId: map['memberId'] as String?,
      memberName: map['memberName'] as String?,
      reviewedByUid: map['reviewedByUid'] as String?,
      reviewComment: map['reviewComment'] as String?,
      reviewedAt: DateTime.tryParse(map['reviewedAt'] as String? ?? ''),
    );
  }
}

String _extractFirstName(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'Sin nombre';
  }
  return parts.first;
}

String _extractLastName(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length < 2) {
    return '';
  }
  return parts.sublist(1).join(' ');
}
