import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';

/// Registro de trabajadores. Los conductores y administradores los asigna
/// un administrador desde la app (pestaña Usuarios).
class RegistroPage extends StatefulWidget {
  const RegistroPage({super.key});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _correo, _clave, _clave2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await AuthService.registrar(
        nombre: _nombre.text,
        correo: _correo.text,
        clave: _clave.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta de trabajador')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Después de crear la cuenta, el administrador te asignará '
                      'tu ruta y tu parada de recogida.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nombre,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Escribe tu nombre'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Escribe un correo válido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _clave,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña (mínimo 6 caracteres)',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _clave2,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Repite la contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v != _clave.text ? 'Las contraseñas no coinciden' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: _cargando ? null : _registrar,
                      child: _cargando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Crear cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
