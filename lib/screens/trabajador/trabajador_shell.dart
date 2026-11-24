import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/geo.dart';
import '../../models/recorrido.dart';
import '../../models/ruta.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/repositorio.dart';
import '../../services/seguimiento_trabajador.dart';
import '../../widgets/comunes.dart';
import '../../widgets/mapa_ruta.dart';
import 'mi_qr_page.dart';

/// Interfaz del **trabajador** (color verde): ve su ruta, el vehículo en vivo,
/// el tiempo estimado de llegada y recibe el aviso de proximidad.
class TrabajadorShell extends StatelessWidget {
  const TrabajadorShell({super.key, required this.usuario});
  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    if (!usuario.tieneRuta) {
      return _SinRuta(usuario: usuario);
    }
    return StreamCacheado<Ruta?>(
      clave: usuario.rutaId,
      crear: () => Repositorio.ruta(usuario.rutaId!),
      builder: (context, snap) {
        if (snap.hasError) {
          return _SinRuta(
              usuario: usuario, detalle: 'No se pudo cargar tu ruta.');
        }
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final ruta = snap.data;
        if (ruta == null) return _SinRuta(usuario: usuario);
        return _TrabajadorConRuta(
          // Si cambia la parada o el trazado, el seguimiento se reinicia.
          key: ValueKey('${ruta.id}-${usuario.paradaIdx}-'
              '${ruta.caminoPolilinea.hashCode}'),
          usuario: usuario,
          ruta: ruta,
        );
      },
    );
  }
}

class _SinRuta extends StatelessWidget {
  const _SinRuta({required this.usuario, this.detalle});
  final Usuario usuario;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BarraRol(usuario: usuario, titulo: 'Rutix'),
      body: Column(
        children: [
          const BannerConexion(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TarjetaRol(usuario: usuario),
                const SizedBox(height: 24),
                MensajeVacio(
                  icono: Icons.hourglass_empty,
                  titulo: 'Aún no tienes una ruta asignada',
                  detalle: detalle ??
                      'Pide al administrador que te asigne una ruta y una parada de recogida.',
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: AuthService.salir,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrabajadorConRuta extends StatefulWidget {
  const _TrabajadorConRuta(
      {super.key, required this.usuario, required this.ruta});
  final Usuario usuario;
  final Ruta ruta;

  @override
  State<_TrabajadorConRuta> createState() => _TrabajadorConRutaState();
}

class _TrabajadorConRutaState extends State<_TrabajadorConRuta> {
  late final SeguimientoTrabajador _seg;
  int _pestana = 0;

  int? get _paradaIdx {
    final i = widget.usuario.paradaIdx;
    return (i != null && i >= 0 && i < widget.ruta.paradas.length) ? i : null;
  }

  LatLng? get _recogida =>
      _paradaIdx == null ? null : widget.ruta.paradas[_paradaIdx!].punto;

  @override
  void initState() {
    super.initState();
    _seg = SeguimientoTrabajador(ruta: widget.ruta, paradaIdx: _paradaIdx)
      ..iniciar();
  }

  @override
  void dispose() {
    _seg.detener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.usuario;
    final ruta = widget.ruta;
    const titulos = ['Inicio', 'Mapa', 'Mi QR y ruta', 'Avisos', 'Perfil'];

    final paginas = [
      _Inicio(
          usuario: u,
          ruta: ruta,
          seg: _seg,
          paradaIdx: _paradaIdx,
          onVerMapa: () => setState(() => _pestana = 1)),
      _Mapa(ruta: ruta, seg: _seg, recogida: _recogida),
      MiQrPage(usuario: u, ruta: ruta, paradaIdx: _paradaIdx),
      _Avisos(seg: _seg),
      PerfilPage(usuario: u, ruta: ruta),
    ];

    return Scaffold(
      appBar: BarraRol(
          usuario: u,
          titulo: titulos[_pestana],
          rutaNombre: '${ruta.nombre} · ${ruta.placa}'),
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
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.qr_code_2), label: 'Mi QR'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Avisos'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
      ),
    );
  }
}

/// Texto de estado del vehículo respecto a la parada del trabajador.
class _EstadoVehiculo {
  final bool activo;
  final double? metros;
  final int? minutos;
  final bool yaPaso;
  const _EstadoVehiculo(this.activo, this.metros, this.minutos, this.yaPaso);

  factory _EstadoVehiculo.de(SeguimientoTrabajador seg) {
    final r = seg.recorrido.value;
    final activo = r != null && r.activo;
    return _EstadoVehiculo(activo, seg.metrosAlVehiculo, seg.minutosEstimados,
        seg.avance?.yaPaso ?? false);
  }

  bool get cerca => metros != null && metros! <= Geo.umbralAvisoMetros;
}

class _Inicio extends StatelessWidget {
  const _Inicio({
    required this.usuario,
    required this.ruta,
    required this.seg,
    required this.paradaIdx,
    required this.onVerMapa,
  });
  final Usuario usuario;
  final Ruta ruta;
  final SeguimientoTrabajador seg;
  final int? paradaIdx;
  final VoidCallback onVerMapa;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<Recorrido?>(
      valueListenable: seg.recorrido,
      builder: (context, _, _) {
        final e = _EstadoVehiculo.de(seg);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TarjetaRol(usuario: usuario),
            const SizedBox(height: 8),
            if (e.cerca)
              Card(
                color: const Color(0xFFFFF3C4),
                child: ListTile(
                  leading: const Icon(Icons.notifications_active,
                      color: Color(0xFF5C4400)),
                  title: const Text('¡Tu transporte está cerca!',
                      style: TextStyle(
                          color: Color(0xFF5C4400),
                          fontWeight: FontWeight.w700)),
                  subtitle: Text('Sal a tu parada: llega en ~${e.minutos} min.',
                      style: const TextStyle(color: Color(0xFF5C4400))),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${ruta.nombre} · ${ruta.turno}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        Chip(
                          avatar: Icon(
                              e.activo ? Icons.directions_bus : Icons.pause,
                              size: 18),
                          label: Text(e.activo ? 'En camino' : 'Sin recorrido'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(paradaIdx == null
                        ? 'Sin parada de recogida asignada'
                        : 'Tu parada: ${ruta.paradas[paradaIdx!].nombre} (${ruta.paradas[paradaIdx!].hora})'),
                    const SizedBox(height: 12),
                    if (e.activo && e.yaPaso)
                      const Text('El vehículo ya pasó por tu parada.',
                          key: Key('ya_paso'),
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700))
                    else if (e.activo && e.minutos != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${e.minutos}',
                              key: const Key('eta_minutos'),
                              style: TextStyle(
                                  fontSize: 44,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  color: color)),
                          const SizedBox(width: 6),
                          Text('min · a ${(e.metros! / 1000).toStringAsFixed(1)} km',
                              style: const TextStyle(fontSize: 16)),
                        ],
                      )
                    else
                      Text(e.activo
                          ? 'El vehículo aún no envía su ubicación.'
                          : 'Tu ruta todavía no ha iniciado el recorrido.'),
                    if (e.activo) ...[
                      const SizedBox(height: 12),
                      IndicadorSenal(ultima: seg.recorrido.value?.actualizado),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: onVerMapa,
                      icon: const Icon(Icons.map),
                      label: const Text('Ver vehículo en el mapa'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Mapa extends StatelessWidget {
  const _Mapa({required this.ruta, required this.seg, this.recogida});
  final Ruta ruta;
  final SeguimientoTrabajador seg;
  final LatLng? recogida;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Recorrido?>(
      valueListenable: seg.recorrido,
      builder: (context, r, _) {
        final e = _EstadoVehiculo.de(seg);
        final vehiculo = (r != null && r.activo) ? r.ubicacion : null;
        return Column(
          children: [
            Expanded(
              child: MapaRuta(
                ruta: ruta,
                vehiculo: vehiculo,
                recogida: recogida,
                etiquetaVehiculo: 'Vehículo ${ruta.placa}',
              ),
            ),
            Material(
              elevation: 8,
              child: ListTile(
                leading: Icon(
                    e.activo ? Icons.directions_bus : Icons.pause_circle_outline,
                    color: Theme.of(context).colorScheme.primary),
                title: Text(e.activo
                    ? (e.yaPaso
                        ? 'Ya pasó por tu parada'
                        : e.minutos != null
                            ? 'Llega en ~${e.minutos} min'
                            : 'Recorrido activo')
                    : 'Sin recorrido activo'),
                subtitle: Text(e.metros != null
                    ? 'A ${e.metros!.round()} m de tu parada por la vía · ${ruta.placa}'
                    : '${ruta.nombre} · ${ruta.placa}'),
                trailing: e.activo
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 170),
                        child: IndicadorSenal(ultima: r?.actualizado),
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Avisos extends StatelessWidget {
  const _Avisos({required this.seg});
  final SeguimientoTrabajador seg;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Aviso>>(
      valueListenable: seg.avisos,
      builder: (context, avisos, _) {
        if (avisos.isEmpty) {
          return const MensajeVacio(
            icono: Icons.notifications_none,
            titulo: 'Sin avisos todavía',
            detalle:
                'Te avisaremos cuando tu ruta inicie y cuando el vehículo esté a 1 km o menos de tu parada.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: avisos.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final a = avisos[i];
            final h = a.hora;
            return ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(a.texto),
              subtitle: Text(
                  '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}'),
            );
          },
        );
      },
    );
  }
}
