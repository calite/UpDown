import 'package:up_down/config/app_config.dart';

/// Roles de usuario dentro de un grupo.
/// - admin: puede asignar directamente positivos/negativos y crear grupos.
/// - user: solo puede sugerir dentro de un grupo.
enum UserRole { admin, user }

/// Representa a un miembro de un equipo.
class Member {
  String name;
  int positives;
  int negatives;
  bool isActive;
  List<HistoryItem> history;
  UserRole role;

  Member({
    required this.name,
    this.positives = 0,
    this.negatives = 0,
    this.isActive = true,
    List<HistoryItem>? history,
    this.role = UserRole.user,
  }) : history = history ?? [];

  /// Calcula el puntaje total en base a la configuración de scoring.
  int get totalScore {
    return (positives * AppConfig.positiveValue) +
        (negatives * AppConfig.negativeValue);
  }
}

/// Configuración de un equipo.
/// Permite ajustar reglas específicas para cada grupo.
class TeamSettings {
  /// Indica si se permiten sugerencias de usuarios que no pertenecen al equipo.
  bool allowExternalSuggestions;

  TeamSettings({this.allowExternalSuggestions = false});
}

/// Representa un equipo con sus miembros, configuración e histórico global.
class Team {
  final String name;
  final List<Member> members;
  bool isActive;
  TeamSettings settings;

  /// Histórico global del equipo (todas las acciones realizadas).
  final List<HistoryItem> teamHistory = [];

  /// Sugerencias pendientes de aprobación/rechazo
  final List<Suggestion> pendingSuggestions = [];

  Team({
    required this.name,
    required this.members,
    this.isActive = true,
    TeamSettings? settings,
  }) : settings = settings ?? TeamSettings();

  /// Devuelve la lista de administradores del equipo.
  List<Member> get admins =>
      members.where((m) => m.role == UserRole.admin).toList();

  /// Agrega un nuevo administrador (solo un admin existente puede hacerlo).
  void addAdmin(Member requester, Member newAdmin) {
    if (requester.role != UserRole.admin) {
      throw Exception("Solo un administrador puede asignar nuevos admins.");
    }
    newAdmin.role = UserRole.admin;
  }

  /// Un usuario sugiere un positivo/negativo → se guarda como pendiente.
  void addSuggestion(Suggestion suggestion) {
    pendingSuggestions.add(suggestion);
  }

  /// Aprueba una sugerencia (solo admins).
  void approveSuggestion(Member requester, Suggestion suggestion) {
    if (requester.role != UserRole.admin) {
      throw Exception("Solo un administrador puede aprobar sugerencias.");
    }
    if (suggestion.approved || suggestion.rejected) {
      throw Exception("La sugerencia ya fue gestionada.");
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
        "APROBADA: ${historyItem.description} (por ${requester.name})",
        DateTime.now(),
      ),
    );

    pendingSuggestions.remove(suggestion);
  }

  /// Rechaza una sugerencia (solo admins).
  void rejectSuggestion(
    Member requester,
    Suggestion suggestion, {
    String? comment,
  }) {
    if (requester.role != UserRole.admin) {
      throw Exception("Solo un administrador puede rechazar sugerencias.");
    }
    if (suggestion.approved || suggestion.rejected) {
      throw Exception("La sugerencia ya fue gestionada.");
    }

    suggestion.rejected = true;
    suggestion.rejectionComment = comment;

    final description =
        "SUGERENCIA RECHAZADA: ${suggestion.from.name} sugirió un "
        "${suggestion.isPositive ? 'positivo' : 'negativo'} para "
        "${suggestion.to.name}. Motivo: ${comment ?? 'no especificado'}";

    suggestion.to.history.add(HistoryItem(description, DateTime.now()));

    teamHistory.add(
      HistoryItem(
        "$description (rechazada por ${requester.name})",
        DateTime.now(),
      ),
    );

    pendingSuggestions.remove(suggestion);
  }

  /// Asigna directamente un positivo/negativo (solo admins).
  void assignDirect({
    required Member requester,
    required Member target,
    required bool isPositive,
    required String comment,
  }) {
    if (requester.role != UserRole.admin) {
      throw Exception(
        "Solo un administrador puede asignar positivos/negativos.",
      );
    }

    if (isPositive) {
      target.positives++;
    } else {
      target.negatives++;
    }

    final description =
        "${isPositive ? 'positivo' : 'negativo'} asignado por ${requester.name} "
        "a ${target.name} ($comment)";

    target.history.add(HistoryItem(description, DateTime.now()));

    teamHistory.add(
      HistoryItem("ASIGNACIÓN DIRECTA: $description", DateTime.now()),
    );
  }
}

/// Elemento histórico de acciones (positivo/negativo aplicado, rechazo, etc.)
class HistoryItem {
  final String description;
  final DateTime date;

  HistoryItem(this.description, this.date);
}

/// Representa una sugerencia hecha por un usuario.
class Suggestion {
  final Member from; // Quién sugiere
  final Member to; // Destinatario
  final bool isPositive;
  final String comment;
  bool approved;
  bool rejected;
  String? rejectionComment;
  DateTime date;

  Suggestion({
    required this.from,
    required this.to,
    required this.isPositive,
    required this.comment,
    this.approved = false,
    this.rejected = false,
    this.rejectionComment,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  String get description =>
      "${from.name} sugirió un ${isPositive ? 'positivo' : 'negativo'} "
      "para ${to.name}: \"$comment\"";

  HistoryItem toHistoryItem() {
    final action = isPositive ? "positivo" : "negativo";
    return HistoryItem("$action para ${to.name} ($comment)", date);
  }
}
