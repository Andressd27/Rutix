import 'package:flutter/material.dart';
import 'home_shell.dart';
import 'models.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _ocultar = true;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  void _ingresar() {
    final correo = _correo.text.trim().toLowerCase();
    final clave = _clave.text;
    final coincidencias =
        usuariosDemo.where((u) => u.correo == correo && u.clave == clave);
    if (coincidencias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo o contraseña incorrectos')),
      );
      return;
    }
    Sesion.actual = coincidencias.first;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_bus, size: 72, color: color),
                const SizedBox(height: 8),
                Text('Rutix',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.bold, color: color)),
                const Text('Tu transporte empresarial, siempre a la vista'),
                const SizedBox(height: 32),
                TextField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _clave,
                  obscureText: _ocultar,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _ocultar ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _ocultar = !_ocultar),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _ingresar,
                    child: const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Demo:\ntrabajador@rutix.com / 1234\nconductor@rutix.com / 1234',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
