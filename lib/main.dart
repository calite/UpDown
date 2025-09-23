import 'package:flutter/material.dart';
import 'package:up_down/pages/settings_page.dart';

// Importamos todas las páginas de la app
import 'pages/login_page.dart';
import 'pages/teams_page.dart';
import 'pages/team_detail_page.dart';
import 'pages/history_page.dart';
import 'pages/stats_page.dart';

void main() {
  runApp(const UpDownApp());
}

/// Widget raíz de la aplicación.
/// Aquí se configura el MaterialApp con las rutas, tema y pantalla inicial.
class UpDownApp extends StatelessWidget {
  const UpDownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // oculta la etiqueta "debug"
      title: 'UpDown', // título de la app
      theme: ThemeData(primarySwatch: Colors.blue), // tema principal (azul)
      // Ruta inicial de la aplicación
      initialRoute: '/',

      // Mapa de rutas de la aplicación
      routes: {
        // Pantalla de login
        '/': (context) => const LoginPage(),

        // Listado de equipos
        '/teams': (context) => const TeamsPage(),

        // Detalle de un equipo (miembros, ranking, etc.)
        '/team-detail': (context) => const TeamDetailPage(),

        // Historial de un miembro
        '/history': (context) => const HistoryPage(),

        // Pantalla de estadísticas globales
        '/stats': (context) => const StatsPage(),

        // Pantalla de opciones
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
