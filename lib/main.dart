import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/data/mock_data.dart';

// Importamos pantallas
import 'pages/login_page.dart';
import 'pages/teams_page.dart';
import 'pages/stats_page.dart';
import 'pages/settings_page.dart';
import 'pages/history_page.dart';
import 'pages/history_tab.dart';
import 'pages/team_details_tab.dart';
import 'pages/pending_suggestions_tab.dart';

void main() {
  runApp(const UpDownApp());
}

/// Widget raíz de la aplicación.
class UpDownApp extends StatelessWidget {
  const UpDownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UpDown',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',

      // Definimos las rutas
      routes: {
        // Pantalla de login
        '/': (context) => const LoginPage(),

        // Listado de equipos
        '/teams': (context) => const TeamsPage(),

        // Detalle de un equipo -> HomePage con tabs
        '/team-detail': (context) => const TeamDetailPageWrapper(),

        // Estadísticas
        '/stats': (context) => const StatsPage(),

        // Configuración
        '/settings': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return SettingsPage(args: args);
        },

        // Histórico de un miembro
        '/history': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          if (args is Member) {
            return HistoryPage(member: args);
          }
          return HistoryPage();
        },
      },
    );
  }
}

/// Wrapper que recibe argumentos y abre HomePage con tabs.
class TeamDetailPageWrapper extends StatelessWidget {
  const TeamDetailPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    final Team team = args['team'] as Team;
    final Member currentUser = args['currentUser'] as Member;
    final List<Suggestion> suggestions =
        args['suggestions'] as List<Suggestion>? ?? [];
    final List<Team> allTeams = args['allTeams'] as List<Team>? ?? mockTeams;

    return HomePage(
      team: team,
      currentUser: currentUser,
      suggestions: suggestions,
      allTeams: allTeams,
    );
  }
}

/// Pantalla principal con tabs (Miembros, Sugerencias, Histórico).
class HomePage extends StatefulWidget {
  final Team team;
  final Member currentUser;
  final List<Suggestion> suggestions;
  final List<Team> allTeams;

  const HomePage({
    super.key,
    required this.team,
    required this.currentUser,
    required this.suggestions,
    required this.allTeams,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TeamDetailsTab(
        team: widget.team,
        currentUser: widget.currentUser,
        allTeams: widget.allTeams,
        suggestions: widget.suggestions,
      ),
      PendingSuggestionsTab(
        team: widget.team,
        currentUser: widget.currentUser,
        suggestions: widget.suggestions,
      ),
      HistoryTab(
        team: widget.team,
        currentUser: widget.currentUser,
        allTeams: widget.allTeams,
        suggestions: widget.suggestions,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.team.name)),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.group), label: "Miembros"),
          BottomNavigationBarItem(
            icon: Icon(Icons.pending_actions),
            label: "Sugerencias",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "Histórico",
          ),
        ],
      ),
    );
  }
}
