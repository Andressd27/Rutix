import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'models.dart';
import 'tracking_service.dart';
import 'ubicacion_service.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final _mapa = MapController();
  final _svc = TrackingService.instancia;
  final _ubicacion = UbicacionService.instancia;
  late final UsuarioDemo _usuario;
  late final Ruta _ruta;
  late final bool _esConductor;
  late final LatLng _recogida;
  bool _mapaListo = false;
  bool _centradoInicial = false;
  bool _mostrarInfo = true;

  @override
  void initState() {
    super.initState();
    _usuario = Sesion.actual!;
    _ruta = rutasDemo.firstWhere((r) => r.id == _usuario.rutaId);
    _esConductor = _usuario.rol == 'conductor';
    _recogida = _ruta.paradas[_usuario.paradaIdx].punto;
    _svc.vehiculo.addListener(_seguirVehiculo);
    _ubicacion.posicion.addListener(_centrarPrimeraVez);
    _ubicacion.iniciar();
  }

  @override
  void dispose() {
    _svc.vehiculo.removeListener(_seguirVehiculo);
    _ubicacion.posicion.removeListener(_centrarPrimeraVez);
    super.dispose();
  }

  static LatLng _aLatLng(Position p) => LatLng(p.latitude, p.longitude);

  void _mover(LatLng p, double zoom) {
    if (!_mapaListo) return;
    _mapa.move(p, zoom);
  }

  void _seguirVehiculo() {
    final p = _svc.vehiculo.value;
    if (p == null) return;
    _mover(p, _mapa.camera.zoom);
  }

  void _centrarPrimeraVez() {
    final p = _ubicacion.posicion.value;
    if (_centradoInicial || p == null || !_mapaListo) return;
    _centradoInicial = true;
    _mover(_aLatLng(p), 16);
  }

  void _irAMiUbicacion() {
    final p = _ubicacion.posicion.value;
    if (p == null) {
      _ubicacion.iniciar();
      return;
    }
    setState(() => _mostrarInfo = true);
    _mover(_aLatLng(p), 16);
  }

  Future<void> _iniciarGps() async {
    final ok = await _svc.iniciarGps(_ruta);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_svc.mensaje.value ?? 'No se pudo iniciar el GPS')),
      );
    }
  }

  void _verDetalles() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_ruta.nombre} · ${_ruta.turno}',
                  style: Theme.of(ctx).textTheme.titleLarge),
              Text('Conductor: ${_ruta.conductor} · Placa: ${_ruta.placa}'),
              const SizedBox(height: 8),
              for (var i = 0; i < _ruta.paradas.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(_ruta.paradas[i].nombre),
                  trailing: Text(_ruta.paradas[i].hora),
                  onTap: () {
                    Navigator.pop(ctx);
                    _mover(_ruta.paradas[i].punto, 16);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verde = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapa,
          options: MapOptions(
            initialCenter: _ruta.paradas[1].punto,
            initialZoom: 13,
            onMapReady: () {
              _mapaListo = true;
              _centrarPrimeraVez();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rutix.app',
              tileBuilder: _mapaSuave,
            ),
            PolylineLayer(polylines: [
              Polyline(points: _ruta.trazado, strokeWidth: 5, color: verde),
            ]),
            MarkerLayer(markers: [
              for (final parada in _ruta.paradas)
                Marker(
                  point: parada.punto,
                  width: 22,
                  height: 22,
                  child: _PuntoParada(color: verde),
                ),
              if (!_esConductor)
                Marker(
                  point: _recogida,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.location_on, color: verde, size: 40),
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
                    child: _MarcadorVehiculo(color: verde),
                  ),
              ]),
            ),
            ValueListenableBuilder<Position?>(
              valueListenable: _ubicacion.posicion,
              builder: (context, pos, _) {
                if (pos == null) return const SizedBox.shrink();
                final punto = _aLatLng(pos);
                return Stack(
                  children: [
                    CircleLayer(circles: [
                      CircleMarker(
                        point: punto,
                        radius: pos.accuracy,
                        useRadiusInMeter: true,
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderColor: Colors.blue.withValues(alpha: 0.4),
                        borderStrokeWidth: 1,
                      ),
                    ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: punto,
                        width: 26,
                        height: 26,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _mostrarInfo = !_mostrarInfo),
                          child: const _PuntoUsuario(),
                        ),
                      ),
                      if (_mostrarInfo)
                        Marker(
                          point: punto,
                          width: 210,
                          height: 96,
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _InfoUbicacion(
                              posicion: pos,
                              onCerrar: () =>
                                  setState(() => _mostrarInfo = false),
                            ),
                          ),
                        ),
                    ]),
                  ],
                );
              },
            ),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),

        // Encabezado (como en el diseño: logo a la izquierda, avatar a la derecha)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Rutix',
                        style: TextStyle(
                            color: verde,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: verde),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _AvisoUbicacion(servicio: _ubicacion),
                _bannerCercania(),
              ],
            ),
          ),
        ),

        // Panel inferior
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _panelInferior(verde),
        ),
      ],
    );
  }

  Widget _bannerCercania() {
    return ValueListenableBuilder<LatLng?>(
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
    );
  }

  Widget _panelInferior(Color verde) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 12),
          child: FloatingActionButton.small(
            heroTag: 'mi_ubicacion',
            backgroundColor: Colors.white,
            foregroundColor: verde,
            tooltip: 'Mi ubicación',
            onPressed: _irAMiUbicacion,
            child: const Icon(Icons.my_location),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: ListenableBuilder(
                listenable: Listenable.merge(
                    [_svc.vehiculo, _svc.fuente, _svc.eventos]),
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _resumenRuta(verde),
                    const SizedBox(height: 12),
                    _esConductor ? _controlesConductor() : _estadoTrabajador(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _verDetalles,
                        child: const Text('Ver detalles'),
                      ),
                    ),
                    if (_svc.eventos.value.isNotEmpty) ...[
                      const Divider(height: 24),
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
      ],
    );
  }

  Widget _resumenRuta(Color verde) {
    final p = _svc.vehiculo.value;
    final activa = _svc.enRecorrido && _svc.rutaActiva?.id == _ruta.id;
    var siguiente = _ruta.paradas.first;
    String? minutos;
    if (activa && p != null) {
      final cercana = TrackingService.paradaMasCercana(p, _ruta);
      final idx = (cercana + 1).clamp(0, _ruta.paradas.length - 1).toInt();
      siguiente = _ruta.paradas[idx];
      final destino = _esConductor ? siguiente.punto : _recogida;
      minutos =
          '${TrackingService.minutosEstimados(TrackingService.metrosHasta(p, destino))} min';
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_ruta.nombre} · ${_ruta.turno}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 2),
              Text('Siguiente parada: ${siguiente.nombre}',
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        if (minutos != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: verde.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(minutos,
                style: TextStyle(color: verde, fontWeight: FontWeight.w700)),
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
            OutlinedButton.icon(
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

  Widget _estadoTrabajador() {
    final p = _svc.vehiculo.value;
    final activa = _svc.enRecorrido && _svc.rutaActiva?.id == _ruta.id;
    if (!activa || p == null) {
      return const Text('Aún no hay un recorrido activo para tu ruta.');
    }
    final m = TrackingService.metrosHasta(p, _recogida);
    final min = TrackingService.minutosEstimados(m);
    return Text(
        'En recorrido · a ${m.round()} m de tu parada · llegada estimada: $min min');
  }
}

// ---------------- Widgets del mapa ----------------

/// Baja la saturación de los tiles para acercarse al mapa gris del diseño.
Widget _mapaSuave(BuildContext context, Widget tile, TileImage _) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(<double>[
      0.37, 0.57, 0.06, 0, 10, //
      0.17, 0.77, 0.06, 0, 10, //
      0.17, 0.57, 0.26, 0, 10, //
      0, 0, 0, 1, 0,
    ]),
    child: tile,
  );
}

class _PuntoUsuario extends StatelessWidget {
  const _PuntoUsuario();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
    );
  }
}

class _PuntoParada extends StatelessWidget {
  final Color color;
  const _PuntoParada({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 4),
      ),
    );
  }
}

class _MarcadorVehiculo extends StatelessWidget {
  final Color color;
  const _MarcadorVehiculo({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Icon(Icons.directions_bus, color: color, size: 24),
    );
  }
}

/// Globo sobre el marcador del usuario con latitud y longitud actuales.
class _InfoUbicacion extends StatelessWidget {
  final Position posicion;
  final VoidCallback onCerrar;
  const _InfoUbicacion({required this.posicion, required this.onCerrar});

  @override
  Widget build(BuildContext context) {
    final t = posicion.timestamp.toLocal();
    final hora =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    const estilo = TextStyle(fontSize: 12, color: Colors.black87);

    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tu ubicación actual',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('Lat: ${posicion.latitude.toStringAsFixed(6)}',
                      style: estilo),
                  Text('Lng: ${posicion.longitude.toStringAsFixed(6)}',
                      style: estilo),
                  Text('±${posicion.accuracy.round()} m · $hora',
                      style: estilo.copyWith(color: Colors.black54)),
                ],
              ),
            ),
            InkWell(
              onTap: onCerrar,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso cuando el GPS está apagado o el permiso fue denegado.
class _AvisoUbicacion extends StatelessWidget {
  final UbicacionService servicio;
  const _AvisoUbicacion({required this.servicio});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoUbicacion>(
      valueListenable: servicio.estado,
      builder: (context, estado, _) {
        final (String texto, String accion, VoidCallback alPulsar) =
            switch (estado) {
          EstadoUbicacion.servicioApagado => (
              'El GPS del teléfono está apagado.',
              'Activar',
              servicio.abrirAjustes,
            ),
          EstadoUbicacion.permisoDenegado => (
              'Rutix necesita permiso para ver tu ubicación.',
              'Permitir',
              servicio.iniciar,
            ),
          EstadoUbicacion.permisoDenegadoSiempre => (
              'El permiso de ubicación está bloqueado. Actívalo en Ajustes.',
              'Ajustes',
              servicio.abrirAjustes,
            ),
          EstadoUbicacion.error => (
              'No se pudo obtener tu ubicación.',
              'Reintentar',
              servicio.iniciar,
            ),
          _ => ('', '', () {}),
        };
        if (texto.isEmpty) return const SizedBox.shrink();
        return Card(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.location_off, color: Colors.redAccent),
            title: Text(texto, style: const TextStyle(fontSize: 14)),
            trailing: TextButton(onPressed: alPulsar, child: Text(accion)),
          ),
        );
      },
    );
  }
}
