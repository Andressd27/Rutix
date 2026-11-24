import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/tema.dart';
import '../models/alerta.dart';
import '../models/usuario.dart';
import '../services/recorrido_conductor.dart';
import '../services/repositorio.dart';
import '../services/ubicacion_service.dart';
import 'comunes.dart';

/// Botón SOS de la barra superior (trabajador y conductor). Siempre visible,
/// a un toque, porque quien espera de noche no puede ponerse a buscar menús.
class BotonEmergencia extends StatelessWidget {
  const BotonEmergencia(
      {super.key, required this.usuario, required this.rutaNombre});
  final Usuario usuario;
  final String rutaNombre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: 'Emergencia',
        child: Material(
          color: colorPeligro,
          shape: const StadiumBorder(
              side: BorderSide(color: Colors.white, width: 1.5)),
          child: InkWell(
            key: const Key('btn_sos'),
            customBorder: const StadiumBorder(),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) =>
                  HojaEmergencia(usuario: usuario, rutaNombre: rutaNombre),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text('SOS',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opciones de emergencia: llamar al 123, llamar a la empresa o enviar una
/// alerta con la ubicación al administrador.
class HojaEmergencia extends StatefulWidget {
  const HojaEmergencia(
      {super.key, required this.usuario, required this.rutaNombre});
  final Usuario usuario;
  final String rutaNombre;

  /// Hora de la última alerta enviada desde este teléfono (evita repetidas).
  static DateTime? ultimaEnviada;

  @override
  State<HojaEmergencia> createState() => _HojaEmergenciaState();
}

class _HojaEmergenciaState extends State<HojaEmergencia> {
  bool _enviando = false;
  String? _mensaje;

  Future<void> _llamar(String numero) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: numero));
    if (!ok && mounted) {
      setState(() => _mensaje = 'No se pudo abrir el teléfono. Marca $numero.');
    }
  }

  /// Ubicación más reciente disponible: la del GPS del conductor si está en
  /// recorrido, o la del teléfono (espera hasta 4 s si aún no la tiene).
  Future<LatLng?> _ubicacion() async {
    final delConductor = RecorridoConductor.instancia.posicion.value;
    if (delConductor != null) return delConductor;
    final servicio = UbicacionService.instancia;
    if (servicio.posicion.value == null) {
      unawaited(servicio.iniciar());
      for (var i = 0; i < 8 && servicio.posicion.value == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    final p = servicio.posicion.value;
    return p == null ? null : LatLng(p.latitude, p.longitude);
  }

  Future<void> _enviarAlerta() async {
    if (!puedeEnviarAlerta(HojaEmergencia.ultimaEnviada, DateTime.now())) {
      setState(() => _mensaje =
          'Ya enviaste una alerta hace menos de un minuto. La empresa ya fue avisada.');
      return;
    }
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: colorPeligro, size: 36),
        title: const Text('¿Enviar alerta de emergencia?'),
        content: const Text(
            'El administrador recibirá tu nombre, tu ruta, la hora y tu '
            'ubicación actual.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: colorPeligro, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar alerta'),
          ),
        ],
      ),
    );
    if (si != true) return;
    setState(() {
      _enviando = true;
      _mensaje = null;
    });
    try {
      final ubicacion = await _ubicacion();
      await Repositorio.enviarAlerta(
        usuario: widget.usuario,
        rutaNombre: widget.rutaNombre,
        ubicacion: ubicacion,
      );
      HojaEmergencia.ultimaEnviada = DateTime.now();
      if (mounted) {
        setState(() => _mensaje = ubicacion == null
            ? 'Alerta enviada (sin ubicación: activa el GPS si puedes).'
            : 'Alerta enviada con tu ubicación.');
      }
    } catch (e) {
      if (mounted) setState(() => _mensaje = 'No se pudo enviar: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Emergencia',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('btn_llamar_123'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: colorPeligro,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _llamar('123'),
              icon: const Icon(Icons.local_phone),
              label: const Text('Llamar al 123 (línea de emergencias)',
                  style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            StreamCacheado<String?>(
              clave: 'telefono_empresa',
              crear: Repositorio.telefonoEmpresa,
              builder: (context, snap) {
                final tel = limpiarTelefono(snap.data);
                if (tel == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: () => _llamar(tel),
                    icon: const Icon(Icons.business),
                    label: Text('Llamar a la empresa ($tel)'),
                  ),
                );
              },
            ),
            OutlinedButton.icon(
              key: const Key('btn_enviar_alerta'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              onPressed: _enviando ? null : _enviarAlerta,
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.campaign),
              label: const Text('Avisar a la empresa con mi ubicación'),
            ),
            if (_mensaje != null) ...[
              const SizedBox(height: 12),
              Text(_mensaje!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            _EstadoMisAlertas(uid: widget.usuario.uid),
          ],
        ),
      ),
    );
  }
}

/// Muestra si la última alerta del usuario ya fue atendida.
class _EstadoMisAlertas extends StatelessWidget {
  const _EstadoMisAlertas({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamCacheado<List<Alerta>>(
      clave: uid,
      crear: () => Repositorio.misAlertas(uid),
      builder: (context, snap) {
        final ultima = snap.data?.firstOrNull;
        if (ultima == null) return const SizedBox.shrink();
        final atendida = ultima.atendida;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: atendida ? const Color(0xFFDDF3E8) : const Color(0xFFFFF3C4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            atendida
                ? 'Tu última alerta (${Alerta.hora(ultima.creada)}) fue atendida'
                    '${ultima.atendidaPor == null ? '' : ' por ${ultima.atendidaPor}'}'
                    ' a las ${Alerta.hora(ultima.atendidaEn)}.'
                : 'Tu alerta de las ${Alerta.hora(ultima.creada)} fue enviada. '
                    'Esperando que la empresa la atienda.',
            style: TextStyle(
                fontSize: 14,
                color: atendida
                    ? const Color(0xFF00573D)
                    : const Color(0xFF5C4400)),
          ),
        );
      },
    );
  }
}
