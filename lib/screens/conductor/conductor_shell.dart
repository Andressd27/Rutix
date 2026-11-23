import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/rol.dart';
import '../../models/recorrido.dart';
import '../../models/ruta.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/recorrido_conductor.dart';
import '../../services/repositorio.dart';
import '../../widgets/comunes.dart';
import '../../widgets/mapa_ruta.dart';

/// Interfaz del **conductor** (color azul): inicia y finaliza el recorrido y
/// comparte su ubicación con los trabajadores de su ruta.
class ConductorShell extends StatelessWidget {
  const ConductorShell({super.key, required this.usuario});
  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    if (!usuario.tieneRuta) return _SinRuta(usuario: usuario);
    return StreamCacheado<Ruta?>(
      clave: usuario.rutaId,
      crear: () => Repositorio.ruta(usuario.rutaId!),
      builder: (context, snap) {
        if (snap.hasError) return _SinRuta(usuario: usuario);
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final ruta = snap.data;
        if (ruta == null) return _SinRuta(usuario: usuario);
        return _ConductorConRuta(usuario: usuario, ruta: ruta);
      },
    );
  }
}

class _SinRuta extends StatelessWidget {
  const _SinRuta({required this.usuario});
  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BarraRol(usuario: usuario, titulo: 'Rutix'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TarjetaRol(usuario: usuario),
          const SizedBox(height: 24),
          const MensajeVacio(
            icono: Icons.no_transfer,
            titulo: 'No tienes una ruta asignada',
            detalle: 'Pide al administrador que te asigne la ruta que conduces.',
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: AuthService.salir,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

class _ConductorConRuta extends StatefulWidget {
  const _ConductorConRuta({required this.usuario, required this.ruta});
  final Usuario usuario;
  final Ruta ruta;

  @override
  State<_ConductorConRuta> createState() => _ConductorConRutaState();
}

class _ConductorConRutaState extends State<_ConductorConRuta> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    final u = widget.usuario;
    final ruta = widget.ruta;
    const titulos = ['Mi recorrido', 'Mi ruta', 'Perfil'];
    final paginas = [
      _Recorrido(usuario: u, ruta: ruta),
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${ruta.nombre} · ${ruta.turno}',
              style: Theme.of(context).textTheme.titleLarge),
          Text('Vehículo: ${ruta.placa}'),
          const SizedBox(height: 8),
          ListaParadas(ruta: ruta),
        ],
      ),
      PerfilPage(usuario: u, ruta: ruta),
    ];

    return Scaffold(
      appBar: BarraRol(usuario: u, titulo: titulos[_pestana]),
      body: Column(
        children: [
          const BannerConexion(),
          Expanded(child: IndexedStack(index: _pestana, children: paginas)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.directions_bus_outlined),
              selectedIcon: Icon(Icons.directions_bus),
              label: 'Recorrido'),
          NavigationDestination(icon: Icon(Icons.alt_route), label: 'Mi ruta'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
      ),
    );
  }
}

class _Recorrido extends StatelessWidget {
  const _Recorrido({required this.usuario, required this.ruta});
  final Usuario usuario;
  final Ruta ruta;

  RecorridoConductor get _rc => RecorridoConductor.instancia;

  Future<void> _iniciar(BuildContext context, {required bool gps}) async {
    final ok = gps
        ? await _rc.iniciarGps(ruta, usuario)
        : await _rc.iniciarSimulacion(ruta, usuario);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_rc.error.value ?? 'No se pudo iniciar el recorrido')));
    }
  }

  Future<void> _confirmarFinalizar(BuildContext context) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Finalizar recorrido?'),
        content: const Text(
            'Los trabajadores dejarán de ver tu ubicación inmediatamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalizar')),
        ],
      ),
    );
    if (si == true) await _rc.finalizar();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_rc.fuente, _rc.posicion]),
      builder: (context, _) {
        final enCurso = _rc.activo;
        return Column(
          children: [
            Expanded(
              child: MapaRuta(
                ruta: ruta,
                vehiculo: _rc.posicion.value,
                etiquetaVehiculo: 'Tu vehículo (${ruta.placa})',
                // En GPS real el punto azul y el vehículo coinciden.
                mostrarMiUbicacion: !enCurso,
              ),
            ),
            Material(
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Rol.conductor.icono,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              enCurso
                                  ? (_rc.fuente.value == FuenteRecorrido.gps
                                      ? 'Recorrido en curso · GPS del teléfono'
                                      : 'Recorrido en curso · simulación')
                                  : '${ruta.nombre} · ${ruta.placa} · detenido',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      _EstadoServidor(rutaId: ruta.id),
                      const SizedBox(height: 8),
                      if (!enCurso) ...[
                        FilledButton.icon(
                          key: const Key('btn_iniciar_gps'),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52)),
                          onPressed: () => _iniciar(context, gps: true),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Iniciar recorrido (GPS)'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48)),
                          onPressed: () => _iniciar(context, gps: false),
                          icon: const Icon(Icons.route),
                          label: const Text('Simular recorrido (demo)'),
                        ),
                      ] else
                        FilledButton.icon(
                          key: const Key('btn_finalizar'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: const Color(0xFFB3261E),
                          ),
                          onPressed: () => _confirmarFinalizar(context),
                          icon: const Icon(Icons.stop),
                          label: const Text('Finalizar recorrido'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Muestra lo que realmente quedó guardado en el servidor (evidencia de RF-02).
class _EstadoServidor extends StatelessWidget {
  const _EstadoServidor({required this.rutaId});
  final String rutaId;

  @override
  Widget build(BuildContext context) {
    return StreamCacheado<Recorrido?>(
      clave: rutaId,
      crear: () => Repositorio.recorrido(rutaId),
      builder: (context, snap) {
        final r = snap.data;
        String texto;
        if (r == null) {
          texto = 'Servidor: sin recorridos registrados';
        } else if (!r.activo) {
          texto = 'Servidor: recorrido inactivo · ubicación no compartida';
        } else {
          final t = r.actualizado;
          final u = r.ubicacion;
          texto = 'Servidor: ubicación compartida'
              '${u == null ? '' : ' (${_fmt(u)})'}'
              '${t == null ? '' : ' · ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}'}';
        }
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(texto, style: const TextStyle(fontSize: 14)),
        );
      },
    );
  }

  static String _fmt(LatLng p) =>
      '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';
}
