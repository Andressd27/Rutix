import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'models.dart';
import 'tracking_service.dart';

class InicioPage extends StatelessWidget {
  final VoidCallback onVerMapa;
  const InicioPage({super.key, required this.onVerMapa});

  @override
  Widget build(BuildContext context) {
    final u = Sesion.actual!;
    final ruta = rutasDemo.firstWhere((r) => r.id == u.rutaId);
    final svc = TrackingService.instancia;

    return ListenableBuilder(
      listenable: Listenable.merge([svc.vehiculo, svc.fuente]),
      builder: (context, _) {
        final p = svc.vehiculo.value;
        final activa = svc.enRecorrido && svc.rutaActiva?.id == ruta.id;

        var siguiente = ruta.paradas.first;
        var progreso = 0.0;
        if (activa && p != null) {
          final cercana = TrackingService.paradaMasCercana(p, ruta);
          final idx = (cercana + 1).clamp(0, ruta.paradas.length - 1).toInt();
          siguiente = ruta.paradas[idx];
          progreso = cercana / (ruta.paradas.length - 1);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hola, ${u.nombre}',
                style: Theme.of(context).textTheme.titleLarge),
            Text(u.rol == 'conductor' ? 'Conductor' : 'Trabajador'),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: ruta.paradas[1].punto,
                    initialZoom: 12,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.rutix',
                    ),
                    PolylineLayer(polylines: [
                      Polyline(
                          points: ruta.trazado,
                          strokeWidth: 4,
                          color: Colors.indigo),
                    ]),
                    MarkerLayer(markers: [
                      if (activa && p != null)
                        Marker(
                          point: p,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.directions_bus,
                              size: 32, color: Colors.green),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Rutas activas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
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
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        Chip(label: Text(activa ? 'En camino' : 'Sin recorrido')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Siguiente parada: ${siguiente.nombre} (${siguiente.hora})'),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: progreso),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onVerMapa,
                      icon: const Icon(Icons.map),
                      label: const Text('Ver en el mapa'),
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
