import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:up_down/pages/login_page.dart';
import 'package:up_down/pages/teams_page.dart';
import 'package:up_down/services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const TeamsPage();
        }

        return const LoginPage();
      },
    );
  }
}
