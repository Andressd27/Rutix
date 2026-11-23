import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/abordaje.dart';
import '../../models/abordaje.dart';
import '../../models/ruta.dart';
import '../../models/usuario.dart';
import '../../services/repositorio.dart';
import '../../widgets/comunes.dart';

/// QR único del trabajador (RF-05) y datos de su ruta.
class MiQrPage extends StatelessWidget {
  const MiQrPage({
    super.key,
    required this.usuario,
    required this.ruta,
    required this.paradaIdx,
  });

  final Usuario usuario;
  final Ruta ruta;
  final int? paradaIdx;

  @override
  Widget build(BuildContext context) {
    final token = usuario.codigoQr;
    final hoy = claveFecha(DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: token == null
                ? const MensajeVacio(
                    icono: Icons.qr_code_2,
                    titulo: 'Aún no tienes código de abordaje',
                    detalle:
                        'El administrador debe volver a guardar tu asignación de ruta para generarlo.',
                  )
                : Column(
                    children: [
                      const Text('Muéstrale este código al conductor al subir',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                          data: CodigoQr(usuario.uid, token).texto,
                          version: QrVersions.auto,
                          size: 240,
                          backgroundColor: Colors.white,
                          semanticsLabel: 'Código QR de abordaje',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(usuario.nombre,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('${ruta.nombre} · ${ruta.turno}'),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(
                              text: CodigoQr(usuario.uid, token).texto));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Código copiado')));
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar código (para pruebas)'),
                      ),
                      const SizedBox(height: 8),
                      StreamCacheado<Abordaje?>(
                        clave: '${ruta.id}-$hoy-${usuario.uid}',
                        crear: () =>
                            Repositorio.abordajeDe(ruta.id, hoy, usuario.uid),
                        builder: (context, snap) {
                          final a = snap.data;
                          final subio = a != null;
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: subio
                                  ? const Color(0xFFDDF3E8)
                                  : const Color(0xFFF1F3F4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                    subio
                                        ? Icons.check_circle
                                        : Icons.schedule,
                                    color: subio
                                        ? const Color(0xFF00573D)
                                        : const Color(0xFF3C4043)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    subio
                                        ? 'Abordaste hoy a las ${a.horaTexto}'
                                        : 'Hoy todavía no registras abordaje',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: subio
                                            ? const Color(0xFF00573D)
                                            : const Color(0xFF3C4043)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Tu ruta', style: Theme.of(context).textTheme.titleLarge),
        Text('Conductor: ${ruta.conductorNombre} · Placa: ${ruta.placa}'),
        const SizedBox(height: 8),
        ListaParadas(ruta: ruta, paradaResaltada: paradaIdx),
      ],
    );
  }
}
