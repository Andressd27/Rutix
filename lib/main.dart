import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';

import 'core/tema.dart';
import 'firebase_options.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/conductor/conductor_shell.dart';
import 'screens/login_page.dart';
import 'screens/trabajador/trabajador_shell.dart';
import 'services/auth_service.dart';
import 'services/conectividad_service.dart';
import 'services/notificaciones_service.dart';
import 'services/recorrido_conductor.dart';
import 'services/sesion_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? errorFirebase;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    errorFirebase = e;
  }
  if (errorFirebase != null) {
    runApp(ErrorConfiguracion(error: errorFirebase));
    return;
  }
  ConectividadService.instancia.iniciar();
  NotificacionesService.instancia.iniciar();
  SesionService.instancia.iniciar();
  runApp(const RutixApp());
}

class RutixApp extends StatefulWidget {
  const RutixApp({super.key});

  @override
  State<RutixApp> createState() => _RutixAppState();
}

class _RutixAppState extends State<RutixApp> {
  final _sesion = SesionService.instancia;

  @override
  void initState() {
    super.initState();
    _sesion.estado.addListener(_alCambiarSesion);
  }

  @override
  void dispose() {
    _sesion.estado.removeListener(_alCambiarSesion);
    super.dispose();
  }

  /// Si el conductor sale o pierde el rol, su ubicación deja de compartirse (RNF-04).
  void _alCambiarSesion() {
    final u = _sesion.usuario;
    if (u == null || !u.esConductor) RecorridoConductor.instancia.finalizar();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoSesion>(
      valueListenable: _sesion.estado,
      builder: (context, estado, _) {
        final usuario = estado is ConSesion ? estado.usuario : null;
        final Widget inicio = switch (estado) {
          SesionCargando() =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
          SinSesion() => const LoginPage(),
          PerfilInvalido(:final mensaje) => _PerfilInvalido(mensaje: mensaje),
          // Cada rol tiene su propia interfaz, con navegación y color propios.
          ConSesion(:final usuario) => usuario.esAdmin
              ? AdminShell(usuario: usuario)
              : usuario.esConductor
                  ? ConductorShell(usuario: usuario)
                  : TrabajadorShell(usuario: usuario),
        };
        return MaterialApp(
          // Cambiar de usuario o de rol reinicia la navegación: ninguna
          // pantalla de un rol queda abierta para otro (RNF-03).
          key: ValueKey('${usuario?.uid}-${usuario?.rol.name}'),
          title: 'Rutix',
          debugShowCheckedModeBanner: false,
          theme: temaPara(usuario?.rol),
          home: inicio,
        );
      },
    );
  }
}

class _PerfilInvalido extends StatelessWidget {
  const _PerfilInvalido({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off, size: 64),
                const SizedBox(height: 16),
                Text(mensaje, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: AuthService.salir,
                    child: const Text('Cerrar sesión')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Se muestra si Firebase no está configurado todavía.
class ErrorConfiguracion extends StatelessWidget {
  const ErrorConfiguracion({super.key, required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaPara(null),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64),
                const SizedBox(height: 16),
                const Text('No se pudo conectar con Firebase',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
