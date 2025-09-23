import 'package:up_down/config/app_config.dart';

class Member {
  String name;
  int positives;
  int negatives;
  bool isActive;
  List<HistoryItem> history;

  Member({
    required this.name,
    this.positives = 0,
    this.negatives = 0,
    this.isActive = true,
    List<HistoryItem>? history,
  }) : history = history ?? [];

  /// Calcula el puntaje total en base a la configuración de scoring.
  int get totalScore {
    return (positives * AppConfig.positiveValue) +
        (negatives * AppConfig.negativeValue);
  }
}

class Team {
  final String name;
  final List<Member> members;
  bool isActive = true;

  Team({required this.name, required this.members, this.isActive = true});
}

class HistoryItem {
  final String description;
  final DateTime date;

  HistoryItem(this.description, this.date);
}
