import 'package:flutter/material.dart';

/// Pantalla inicial de la app.
/// De momento es un login muy básico con un solo botón para ir a la página de equipos.
/// Más adelante aquí se podrá integrar Firebase Auth o cualquier sistema de autenticación.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar con el título de la app
      appBar: AppBar(title: const Text("UpDown - Login")),

      // Cuerpo de la pantalla
      body: Center(
        // Botón principal de inicio de sesión
        child: ElevatedButton(
          // Acción al pulsar el botón
          onPressed: () {
            // Navegamos a la página de equipos y reemplazamos el login
            // (para que no se pueda volver atrás con el botón "atrás")
            Navigator.pushReplacementNamed(context, '/teams');
          },
          // Texto dentro del botón
          child: const Text("Iniciar sesión"),
        ),
      ),
    );
  }
}
