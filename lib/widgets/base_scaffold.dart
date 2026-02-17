import 'package:flutter/material.dart';
import 'package:up_down/widgets/app_drawer.dart';

/// Scaffold base con AppBar y Drawer a la derecha.
/// Se encarga de mostrar el botón del menú en la parte superior derecha.
class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Map<String, dynamic> args;
  final FloatingActionButton? floatingActionButton;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.args,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: AppDrawer(args: args),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9FBFF), Color(0xFFF1F5FC)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: body,
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
