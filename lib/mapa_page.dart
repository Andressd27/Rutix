import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'models.dart';
import 'tracking_service.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final _mapa = MapController();
  final _svc = TrackingService.instancia;
  late final UsuarioDemo _usuario;
  late final Ruta _ruta;
  late final bool _esConductor;
  late final LatLng _recogida;

  @override
  void initState() {
    super.initState();
    _usuario = Sesion.actual!;
    _ruta = rutasDemo.firstWhere((r) => r.id == _usuario.rutaId);
    _esConductor = _usuario.rol == 'conductor';
    _recogida = _ruta.paradas[_usuario.paradaIdx].punto;
    _svc.vehiculo.addListener(_seguirVehiculo);
  }

  @override
  void dispose() {
    _svc.vehiculo.removeListener(_seguirVehiculo);
    super.dispose();
  }

  void _seguirVehiculo() {
    final p = _svc.vehiculo.value;
    if (p == null) return;
    try {
      _mapa.move(p, _mapa.camera.zoom);
    } catch (_) {
      // El mapa aún no está dibujado; se ignora.
    }
  }

  Future<void> _iniciarGps() async {
    final ok = await _svc.iniciarGps(_ruta);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_svc.mensaje.value ?? 'No se pudo iniciar el GPS')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapa,
          options: MapOptions(
            initialCenter: _ruta.paradas[1].punto,
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.rutix',
            ),
            PolylineLayer(polylines: [
              Polyline(points: _ruta.trazado, strokeWidth: 4, color: Colors.indigo),
            ]),
            MarkerLayer(markers: [
              for (final parada in _ruta.paradas)
                Marker(
                  point: parada.punto,
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                ),
              if (!_esConductor)
                Marker(
                  point: _recogida,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.person_pin_circle,
                      color: Colors.blue, size: 36),
                ),
            ]),
            ValueListenableBuilder<LatLng?>(
              valueListenable: _svc.vehiculo,
              builder: (context, p, _) => MarkerLayer(markers: [
                if (p != null)
                  Marker(
                    point: p,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.directions_bus,
                        size: 36, color: Colors.green),
                  ),
              ]),
            ),
          ],
        ),

        // Banner "¡Tu transporte está cerca!" (solo trabajador)
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: ValueListenableBuilder<LatLng?>(
            valueListenable: _svc.vehiculo,
            builder: (context, p, _) {
              if (_esConductor || p == null) return const SizedBox.shrink();
              final m = TrackingService.metrosHasta(p, _recogida);
              if (m > TrackingService.umbralCercaniaMetros) {
                return const SizedBox.shrink();
              }
              return Card(
                color: Colors.amber.shade100,
                child: ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: const Text('¡Tu transporte está cerca!'),
                  subtitle: Text('A ${m.round()} m de tu punto de recogida'),
                ),
              );
            },
          ),
        ),

        // Panel inferior
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Card(
            margin: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: ListenableBuilder(
                  listenable:
                      Listenable.merge([_svc.vehiculo, _svc.fuente, _svc.eventos]),
                  builder: (context, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_ruta.nombre} · ${_ruta.turno}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      _esConductor ? _controlesConductor() : _estadoTrabajador(),
                      if (_svc.eventos.value.isNotEmpty) ...[
                        const Divider(),
                        for (final e in _svc.eventos.value.take(3))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(e.icono),
                            title: Text(e.texto),
                            subtitle: Text(e.hace),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _controlesConductor() {
    final enCurso = _svc.enRecorrido;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(enCurso
            ? (_svc.fuente.value == Fuente.gps
                ? 'Recorrido en curso (GPS del teléfono)'
                : 'Recorrido en curso (simulación)')
            : 'Recorrido detenido'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: enCurso ? null : _iniciarGps,
              icon: const Icon(Icons.gps_fixed),
              label: const Text('Iniciar con GPS'),
            ),
            OutlinedButton.icon(
              onPressed: enCurso ? null : () => _svc.iniciarSimulacion(_ruta),
              icon: const Icon(Icons.route),
              label: const Text('Simular recorrido'),
            ),
            TextButton.icon(
              onPressed: enCurso ? _svc.finalizar : null,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Finalizar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _estadoTabajadorSinRecorrido() =>
      const Text('Aún no hay un recorrido activo para tu ruta.');

  Widget _estadoTrabajador() {
    final p = _svc.vehiculo.value;
    final activa = _svc.enRecorrido && _svc.rutaActiva?.id == _ruta.id;
    if (!activa || p == null) return _estadoTabajadorSinRecorrido();
    final m = TrackingService.metrosHasta(p, _recogida);
    final min = TrackingService.minutosEstimados(m);
    return Text('En recorrido · a ${m.round()} m de tu parada · llegada estimada: $min min');
  }
}
