import '../models/models.dart';

final mockTeams = [
  Team(
    name: "Equipo Alpha",
    members: [
      Member(name: "Pedro", positives: 5, negatives: 2, role: UserRole.admin),
      Member(name: "Laura", positives: 3, negatives: 0, role: UserRole.user),
    ],
  ),
  Team(
    name: "Equipo Beta",
    members: [
      Member(name: "Ana", positives: 7, negatives: 1, role: UserRole.admin),
      Member(name: "Carlos", positives: 2, negatives: 4, role: UserRole.user),
    ],
  ),
];

/// Sugerencias iniciales de ejemplo
final mockSuggestions = [
  Suggestion(
    from: mockTeams[0].members[1], // Laura
    to: mockTeams[0].members[0], // Pedro
    isPositive: true,
    comment: "Gran liderazgo en la última reunión",
  ),
  Suggestion(
    from: mockTeams[1].members[1], // Carlos
    to: mockTeams[1].members[0], // Ana
    isPositive: false,
    comment: "Se retrasó en la entrega del informe",
  ),
];
