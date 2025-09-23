import 'package:flutter/material.dart';

/// Widget reutilizable que representa el menú lateral (Drawer).
/// Se incluye en todas las pantallas principales mediante:
///   drawer: const AppDrawer()
/// en el Scaffold.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      // ListView para mostrar las opciones del menú
      child: ListView(
        padding: EdgeInsets.zero, // sin margen extra arriba
        children: [
          // Cabecera superior del menú
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              "Menú",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),

          // Opción: navegar a Mis equipos
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text("Mis equipos"),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/teams');
            },
          ),

          // Opción: navegar a Estadísticas
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text("Estadísticas"),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/stats');
            },
          ),

          // Opción: navegar a Configuración
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Configuración"),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/settings');
            },
          ),

          // Opción: cerrar sesión y volver al login
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Cerrar sesión"),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
    );
  }
}
