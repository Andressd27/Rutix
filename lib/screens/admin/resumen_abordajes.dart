import 'package:material_ui/material_ui.dart';

import '../../core/abordaje.dart';
import '../../models/abordaje.dart';
import '../../models/ruta.dart';
import '../../services/repositorio.dart';
import '../../widgets/comunes.dart';

/// RF-06: por ruta y fecha, cuántos trabajadores abordaron frente a los asignados.
class ResumenAbordajes extends StatefulWidget {
  const ResumenAbordajes({super.key, required this.rutas});
  final List<Ruta> rutas;

  @override
  State<ResumenAbordajes> createState() => _ResumenAbordajesState();
}

class _ResumenAbordajesState extends State<ResumenAbordajes> {
  DateTime _fecha = DateTime.now();

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 1),
      lastDate: hoy,
      helpText: 'Fecha del resumen',
    );
    if (f != null) setState(() => _fecha = f);
  }

  @override
  Widget build(BuildContext context) {
    final fecha = claveFecha(_fecha);
    final esHoy = fecha == claveFecha(DateTime.now());
    if (widget.rutas.isEmpty) {
      return const MensajeVacio(
        icono: Icons.alt_route,
        titulo: 'Todavía no hay rutas',
        detalle: 'Crea o carga rutas en la pestaña Rutas.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text(esHoy ? 'Hoy · $fecha' : fecha),
            subtitle: const Text('Toca para cambiar la fecha'),
            trailing: const Icon(Icons.edit_calendar),
            onTap: _elegirFecha,
          ),
        ),
        const SizedBox(height: 8),
        for (final r in widget.rutas)
          _TarjetaRuta(key: ValueKey('${r.id}-$fecha'), ruta: r, fecha: fecha),
      ],
    );
  }
}

class _TarjetaRuta extends StatelessWidget {
  const _TarjetaRuta({super.key, required this.ruta, required this.fecha});
  final Ruta ruta;
  final String fecha;

  @override
  Widget build(BuildContext context) {
    return StreamCacheado<List<Pasajero>>(
      clave: ruta.id,
      crear: () => Repositorio.pasajeros(ruta.id),
      builder: (context, sp) => StreamCacheado<List<Abordaje>>(
        clave: '${ruta.id}-$fecha',
        crear: () => Repositorio.abordajes(ruta.id, fecha),
        builder: (context, sa) {
          if (sp.hasError || sa.hasError) {
            return Card(
              child: ListTile(
                title: Text(ruta.nombre),
                subtitle: Text('Error: ${sp.error ?? sa.error}'),
              ),
            );
          }
          final pasajeros = sp.data;
          final abordajes = sa.data;
          if (pasajeros == null || abordajes == null) {
            return const Card(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator())));
          }
          return TarjetaAbordaje(
            ruta: ruta,
            pasajeros: pasajeros,
            abordajes: abordajes,
          );
        },
      ),
    );
  }
}

/// Tarjeta "X de Y" con quién abordó y quién falta. También la usa el conductor.
class TarjetaAbordaje extends StatelessWidget {
  const TarjetaAbordaje({
    super.key,
    required this.ruta,
    required this.pasajeros,
    required this.abordajes,
    this.inicialmenteAbierta = false,
  });

  final Ruta ruta;
  final List<Pasajero> pasajeros;
  final List<Abordaje> abordajes;
  final bool inicialmenteAbierta;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final abordaron = {for (final a in abordajes) a.uid: a};
    final asignados = pasajeros.length;
    final cuenta =
        contarAbordaron(pasajeros.map((p) => p.uid), abordaron.keys);
    final progreso = asignados == 0 ? 0.0 : cuenta / asignados;
    final faltan = pasajeros.where((p) => !abordaron.containsKey(p.uid));

    return Card(
      child: ExpansionTile(
        initiallyExpanded: inicialmenteAbierta,
        title: Text('${ruta.nombre} · ${ruta.turno}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              asignados == 0
                  ? 'Sin trabajadores asignados'
                  : 'Abordaron ${resumenAbordaje(cuenta, asignados)}',
              key: Key('resumen_${ruta.id}'),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progreso, minHeight: 8),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          for (final p in pasajeros.where((p) => abordaron.containsKey(p.uid)))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle, color: Color(0xFF007A55)),
              title: Text(p.nombre),
              trailing: Text(abordaron[p.uid]!.horaTexto),
            ),
          for (final p in faltan)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.radio_button_unchecked),
              title: Text(p.nombre),
              trailing: const Text('Pendiente'),
            ),
          if (asignados == 0)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                  'Asigna trabajadores a esta ruta desde la pestaña Usuarios.'),
            ),
        ],
      ),
    );
  }
}
