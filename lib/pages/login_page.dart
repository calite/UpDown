import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:up_down/config/error_titles.dart';
import 'package:up_down/services/auth_service.dart';
import 'package:up_down/widgets/error_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isRegisterMode) {
        await AuthService.instance.register(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          lastName: _lastNameController.text.trim(),
        );
      } else {
        await AuthService.instance.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      await showErrorDialog(
        context,
        title: ErrorTitles.auth,
        message: _friendlyAuthError(e, isRegisterMode: _isRegisterMode),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _friendlyAuthError(
    Object error, {
    required bool isRegisterMode,
  }) {
    if (error is FirebaseAuthException) {
      if (!isRegisterMode) {
        switch (error.code) {
          case 'invalid-credential':
          case 'wrong-password':
          case 'user-not-found':
          case 'invalid-email':
            return 'Credenciales o usuario incorrecto.';
        }
      }
      switch (error.code) {
        case 'invalid-email':
          return 'El correo ingresado no es valido.';
        case 'too-many-requests':
          return 'Demasiados intentos fallidos. Intenta nuevamente en unos minutos.';
        case 'network-request-failed':
          return 'No se pudo conectar. Revisa tu conexion e intenta de nuevo.';
        case 'email-already-in-use':
          return 'Ese correo ya esta registrado.';
        case 'weak-password':
          return 'La contrasena es demasiado debil.';
      }
    }
    return 'No se pudo completar la autenticacion. Intenta nuevamente.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegisterMode ? 'Registro' : 'Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isRegisterMode ? 'Crear cuenta' : 'Acceder',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (_isRegisterMode) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Nombre'),
                          validator: (value) {
                            if (_isRegisterMode &&
                                (value == null || value.trim().isEmpty)) {
                              return 'El nombre es obligatorio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(labelText: 'Apellidos'),
                          validator: (value) {
                            if (_isRegisterMode &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Los apellidos son obligatorios';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty || !email.contains('@')) {
                            return 'Ingresa un email valido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                        validator: (value) {
                          if ((value?.length ?? 0) < 6) {
                            return 'Minimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isRegisterMode ? 'Registrarme' : 'Entrar'),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() => _isRegisterMode = !_isRegisterMode);
                              },
                        child: Text(
                          _isRegisterMode
                              ? 'Ya tengo cuenta'
                              : 'No tengo cuenta, registrarme',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
