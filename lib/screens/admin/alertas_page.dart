import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tema.dart';
import '../../models/alerta.dart';
import '../../models/usuario.dart';
import '../../services/repositorio.dart';
import '../../widgets/comunes.dart';

/// Alertas de emergencia enviadas por trabajadores y conductores.
class AlertasPage extends StatelessWidget {
  const AlertasPage({super.key, required this.admin, required this.alertas});
  final Usuario admin;
  final List<Alerta>? alertas;

  @override
  Widget build(BuildContext context) {
    final lista = alertas;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _TelefonoEmpresa(),
        const SizedBox(height: 8),
        if (lista == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (lista.isEmpty)
          const MensajeVacio(
            icono: Icons.verified_user,
            titulo: 'Sin alertas',
            detalle: 'Aquí aparecen las alertas que envían los trabajadores y '
                'conductores con el botón SOS.',
          )
        else
          for (final a in lista) _TarjetaAlerta(alerta: a, admin: admin),
      ],
    );
  }
}

class _TarjetaAlerta extends StatelessWidget {
  const _TarjetaAlerta({required this.alerta, required this.admin});
  final Alerta alerta;
  final Usuario admin;

  void _verMapa(BuildContext context) {
    final p = alerta.ubicacion!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ubicación de ${alerta.nombre}'),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        content: SizedBox(
          width: 360,
          height: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(initialCenter: p, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'co.edu.uts.rutix',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: p,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on,
                        color: colorPeligro, size: 44),
                  ),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => launchUrl(Uri.parse(
                'https://www.openstreetmap.org/?mlat=${p.latitude}&mlon=${p.longitude}#map=17/${p.latitude}/${p.longitude}')),
            child: const Text('Abrir en el navegador'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = alerta;
    final pendiente = !a.atendida;
    final fondo = pendiente ? const Color(0xFFFCE8E6) : null;
    final texto = pendiente ? const Color(0xFF8C1D18) : null;
    return Card(
      color: fondo,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(pendiente ? Icons.warning_amber : Icons.check_circle,
                    color: pendiente ? colorPeligro : const Color(0xFF007A55)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(a.nombre,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: texto)),
                ),
                InsigniaRol(rol: a.rol),
              ],
            ),
            const SizedBox(height: 6),
            Text('${a.rutaNombre} · ${Alerta.hora(a.creada)}',
                style: TextStyle(color: texto)),
            Text(
              pendiente
                  ? 'Pendiente'
                  : 'Atendida por ${a.atendidaPor ?? '—'} a las ${Alerta.hora(a.atendidaEn)}',
              style: TextStyle(color: texto, fontWeight: FontWeight.w600),
            ),
            if (a.ubicacion == null)
              Text('Sin ubicación (el teléfono no tenía GPS activo).',
                  style: TextStyle(color: texto)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (a.ubicacion != null)
                  OutlinedButton.icon(
                    onPressed: () => _verMapa(context),
                    icon: const Icon(Icons.map),
                    label: const Text('Ver ubicación'),
                  ),
                if (pendiente)
                  FilledButton.icon(
                    key: Key('atender_${a.id}'),
                    onPressed: () async {
                      try {
                        await Repositorio.atenderAlerta(a.id, admin);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('No se pudo actualizar: $e')));
                        }
                      }
                    },
                    icon: const Icon(Icons.done),
                    label: const Text('Marcar atendida'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Teléfono de la empresa que ven trabajadores y conductores en el SOS.
class _TelefonoEmpresa extends StatelessWidget {
  const _TelefonoEmpresa();

  Future<void> _editar(BuildContext context, String? actual) async {
    final control = TextEditingController(text: actual ?? '');
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teléfono de la empresa'),
        content: TextField(
          controller: control,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Número para emergencias',
            hintText: 'Ej.: 3001234567',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, control.text),
              child: const Text('Guardar')),
        ],
      ),
    );
    control.dispose();
    if (nuevo == null) return;
    if (nuevo.trim().isNotEmpty && limpiarTelefono(nuevo) == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Escribe un número válido.')));
      }
      return;
    }
    await Repositorio.guardarTelefonoEmpresa(nuevo);
  }

  @override
  Widget build(BuildContext context) {
    return StreamCacheado<String?>(
      clave: 'telefono_empresa',
      crear: Repositorio.telefonoEmpresa,
      builder: (context, snap) {
        final tel = snap.data;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Teléfono de la empresa'),
            subtitle: Text(tel == null || tel.isEmpty
                ? 'Sin configurar: el SOS solo ofrecerá llamar al 123'
                : tel),
            trailing: const Icon(Icons.edit),
            onTap: () => _editar(context, tel),
          ),
        );
      },
    );
  }
}
