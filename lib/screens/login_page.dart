import 'package:material_ui/material_ui.dart';

import '../core/rol.dart';
import '../services/auth_service.dart';
import 'registro_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _ocultar = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await AuthService.ingresar(_correo.text, _clave.text);
      // La sesión la detecta SesionService y la app cambia de pantalla sola.
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.directions_bus, size: 72, color: color),
                    const SizedBox(height: 8),
                    Text('Rutix',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.bold, color: color)),
                    const Text('Tu transporte empresarial, siempre a la vista',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
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
                      obscureText: _ocultar,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _ingresar(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _ocultar ? 'Mostrar' : 'Ocultar',
                          icon: Icon(_ocultar
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(() => _ocultar = !_ocultar),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Escribe tu contraseña' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!,
                          key: const Key('error_login'),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 14)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: _cargando ? null : _ingresar,
                      child: _cargando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Iniciar sesión'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _cargando
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RegistroPage()),
                              ),
                      child: const Text('¿Eres trabajador nuevo? Crea tu cuenta'),
                    ),
                    const SizedBox(height: 24),
                    const _LeyendaRoles(),
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

/// Muestra desde el inicio que cada rol tiene su propio color.
class _LeyendaRoles extends StatelessWidget {
  const _LeyendaRoles();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final r in Rol.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(r.icono, color: r.color, size: 20),
              const SizedBox(width: 4),
              Text(r.etiqueta, style: TextStyle(color: r.color, fontSize: 14)),
            ],
          ),
      ],
    );
  }
}
