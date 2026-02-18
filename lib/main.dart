import 'package:flutter/material.dart';
import 'package:up_down/firebase_bootstrap.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/pages/auth_gate.dart';
import 'package:up_down/pages/history_page.dart';
import 'package:up_down/pages/link_requests_page.dart';
import 'package:up_down/pages/settings_page.dart';
import 'package:up_down/pages/stats_page.dart';
import 'package:up_down/pages/team_detail_page_wrapper.dart';
import 'package:up_down/pages/teams_page.dart';
import 'package:up_down/pages/user_roles_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  runApp(const UpDownApp());
}

class UpDownApp extends StatelessWidget {
  const UpDownApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B5FFF),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UpDown',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF12233D),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF12233D),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE3E9F2)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD5DEEA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD5DEEA)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        ),
      ),
      home: const AuthGate(),
      routes: {
        '/teams': (context) => const TeamsPage(),
        '/team-detail': (context) => const TeamDetailPageWrapper(),
        '/stats': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return StatsPage(args: args);
        },
        '/settings': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return SettingsPage(args: args);
        },
        '/history': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Member) {
            return HistoryPage(member: args);
          }
          return HistoryPage();
        },
        '/link-requests': (context) => const LinkRequestsPage(),
        '/user-roles': (context) => const UserRolesPage(),
      },
    );
  }
}
