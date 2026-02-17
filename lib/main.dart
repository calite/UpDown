import 'package:flutter/material.dart';
import 'package:up_down/firebase_bootstrap.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/pages/auth_gate.dart';
import 'package:up_down/pages/history_page.dart';
import 'package:up_down/pages/settings_page.dart';
import 'package:up_down/pages/stats_page.dart';
import 'package:up_down/pages/team_detail_page_wrapper.dart';
import 'package:up_down/pages/teams_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  runApp(const UpDownApp());
}

class UpDownApp extends StatelessWidget {
  const UpDownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UpDown',
      theme: ThemeData(primarySwatch: Colors.blue),
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
      },
    );
  }
}
