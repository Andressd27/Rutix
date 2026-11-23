import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../models/ruta.dart';
import '../services/ubicacion_service.dart';

/// Mapa compartido por trabajador y conductor: trazado de la ruta, paradas,
/// vehículo, parada de recogida y la ubicación del propio teléfono.
class MapaRuta extends StatefulWidget {
  const MapaRuta({
    super.key,
    required this.ruta,
    this.vehiculo,
    this.recogida,
    this.etiquetaVehiculo = 'Vehículo',
    this.seguirVehiculo = true,
    this.mostrarMiUbicacion = true,
  });

  final Ruta ruta;
  final LatLng? vehiculo;
  final LatLng? recogida;
  final String etiquetaVehiculo;
  final bool seguirVehiculo;
  final bool mostrarMiUbicacion;

  @override
  State<MapaRuta> createState() => _MapaRutaState();
}

class _MapaRutaState extends State<MapaRuta> {
  final _mapa = MapController();
  final _ubicacion = UbicacionService.instancia;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    if (widget.mostrarMiUbicacion) _ubicacion.iniciar();
  }

  @override
  void didUpdateWidget(MapaRuta old) {
    super.didUpdateWidget(old);
    final v = widget.vehiculo;
    if (_listo && widget.seguirVehiculo && v != null && v != old.vehiculo) {
      _mapa.move(v, _mapa.camera.zoom);
    }
  }

  void _centrarEn(LatLng p) {
    if (_listo) _mapa.move(p, 16);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final ruta = widget.ruta;
    final centro = widget.vehiculo ??
        widget.recogida ??
        (ruta.paradas.isNotEmpty
            ? ruta.paradas[ruta.paradas.length ~/ 2].punto
            : const LatLng(7.1193, -73.1227));

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapa,
          options: MapOptions(
            initialCenter: centro,
            initialZoom: 13,
            onMapReady: () => _listo = true,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'co.edu.uts.rutix',
            ),
            if (ruta.paradas.length > 1)
              PolylineLayer(polylines: [
                Polyline(points: ruta.trazado, strokeWidth: 5, color: color),
              ]),
            MarkerLayer(markers: [
              for (final p in ruta.paradas)
                Marker(
                  point: p.punto,
                  width: 22,
                  height: 22,
                  child: Tooltip(
                    message: '${p.nombre} · ${p.hora}',
                    child: _Punto(color: color),
                  ),
                ),
              if (widget.recogida != null)
                Marker(
                  point: widget.recogida!,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: Tooltip(
                    message: 'Tu parada de recogida',
                    child: Icon(Icons.location_on, color: color, size: 44),
                  ),
                ),
            ]),
            if (widget.mostrarMiUbicacion)
              ValueListenableBuilder<Position?>(
                valueListenable: _ubicacion.posicion,
                builder: (context, pos, _) {
                  if (pos == null) return const SizedBox.shrink();
                  final punto = LatLng(pos.latitude, pos.longitude);
                  return Stack(children: [
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
                        width: 24,
                        height: 24,
                        child: const _MiPunto(),
                      ),
                    ]),
                  ]);
                },
              ),
            if (widget.vehiculo != null)
              MarkerLayer(markers: [
                Marker(
                  point: widget.vehiculo!,
                  width: 48,
                  height: 48,
                  child: Tooltip(
                    message: widget.etiquetaVehiculo,
                    child: _Vehiculo(color: color),
                  ),
                ),
              ]),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              if (widget.vehiculo != null)
                _BotonMapa(
                  icono: Icons.directions_bus,
                  ayuda: 'Ver vehículo',
                  onPressed: () => _centrarEn(widget.vehiculo!),
                ),
              if (widget.recogida != null)
                _BotonMapa(
                  icono: Icons.location_on,
                  ayuda: 'Ver mi parada',
                  onPressed: () => _centrarEn(widget.recogida!),
                ),
              if (widget.mostrarMiUbicacion)
                _BotonMapa(
                  icono: Icons.my_location,
                  ayuda: 'Mi ubicación',
                  onPressed: () {
                    final p = _ubicacion.posicion.value;
                    if (p == null) {
                      _ubicacion.iniciar();
                    } else {
                      _centrarEn(LatLng(p.latitude, p.longitude));
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BotonMapa extends StatelessWidget {
  const _BotonMapa(
      {required this.icono, required this.ayuda, required this.onPressed});
  final IconData icono;
  final String ayuda;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FloatingActionButton.small(
        heroTag: ayuda,
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).colorScheme.primary,
        tooltip: ayuda,
        onPressed: onPressed,
        child: Icon(icono),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 4),
        ),
      );
}

class _MiPunto extends StatelessWidget {
  const _MiPunto();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
      );
}

class _Vehiculo extends StatelessWidget {
  const _Vehiculo({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
        ),
        child: const Icon(Icons.directions_bus, color: Colors.white, size: 26),
      );
}
