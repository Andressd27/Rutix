import 'package:flutter/material.dart';
import 'models.dart';
import 'tracking_service.dart';

class MisRutasPage extends StatelessWidget {
  const MisRutasPage({super.key});

  void _detalles(BuildContext context, Ruta r) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.nombre} · ${r.turno}',
                style: Theme.of(ctx).textTheme.titleLarge),
            Text('Conductor: ${r.conductor} · Placa: ${r.placa}'),
            const SizedBox(height: 8),
            for (var i = 0; i < r.paradas.length; i++)
              ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(r.paradas[i].nombre),
                trailing: Text(r.paradas[i].hora),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = Sesion.actual!;
    final svc = TrackingService.instancia;

    return ListenableBuilder(
      listenable: svc.fuente,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Mis rutas', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final r in rutasDemo)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              '${r.nombre}${r.id == u.rutaId ? '  (asignada)' : ''}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        Chip(
                          label: Text(
                              svc.enRecorrido && svc.rutaActiva?.id == r.id
                                  ? 'Activa'
                                  : 'Inactiva'),
                        ),
                      ],
                    ),
                    Text('${r.turno} · ${r.conductor}'),
                    const SizedBox(height: 4),
                    Text('Primera parada: ${r.paradas.first.nombre} - ${r.paradas.first.hora}'),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _detalles(context, r),
                        child: const Text('Ver detalles'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
