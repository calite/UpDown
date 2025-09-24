import 'package:flutter/material.dart';
import 'package:up_down/models/models.dart';
import 'package:up_down/data/mock_data.dart'; // donde tienes mockTeams

/// Pantalla de login de prueba.
/// Permite elegir entre Admin o Member para testear los roles.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text("Login como Admin"),
              onPressed: () {
                // Creamos un usuario administrador
                final adminUser = Member(
                  name: "Admin Demo",
                  role: UserRole.admin,
                );

                // Navegamos a la lista de equipos
                Navigator.pushReplacementNamed(
                  context,
                  '/teams',
                  arguments: {
                    'currentUser': adminUser,
                    'teams': mockTeams,
                    'suggestions': <Suggestion>[], // lista vacía inicial
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.person),
              label: const Text("Login como Miembro"),
              onPressed: () {
                // Creamos un usuario normal
                final memberUser = Member(
                  name: "Usuario Demo",
                  role: UserRole.user,
                );

                Navigator.pushReplacementNamed(
                  context,
                  '/teams',
                  arguments: {
                    'currentUser': memberUser,
                    'teams': mockTeams,
                    'suggestions': <Suggestion>[],
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
