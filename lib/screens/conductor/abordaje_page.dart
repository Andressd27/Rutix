import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/abordaje.dart';
import '../../models/abordaje.dart';
import '../../models/ruta.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/repositorio.dart';
import '../../widgets/comunes.dart';
import '../admin/resumen_abordajes.dart';

/// El conductor registra el abordaje escaneando el QR del trabajador (RF-05).
class AbordajePage extends StatefulWidget {
  const AbordajePage({super.key, required this.conductor, required this.ruta});
  final Usuario conductor;
  final Ruta ruta;

  @override
  State<AbordajePage> createState() => _AbordajePageState();
}

class _AbordajePageState extends State<AbordajePage> {
  bool _procesando = false;
  ResultadoAbordaje? _resultado;
  String? _nombre;
  String? _error;

  Future<void> _escanear() async {
    final texto = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _Escaner()),
    );
    if (texto != null) await _registrar(texto);
  }

  Future<void> _ingresarManual() async {
    final control = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ingresar código'),
        content: TextField(
          controller: control,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Texto del QR (rutix:v1:…)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, control.text),
              child: const Text('Registrar')),
        ],
      ),
    );
    control.dispose();
    if (texto != null && texto.trim().isNotEmpty) await _registrar(texto);
  }

  Future<void> _registrar(String texto) async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      final (resultado, nombre) = await Repositorio.registrarAbordaje(
        rutaId: widget.ruta.id,
        conductor: widget.conductor,
        textoQr: texto,
      );
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _nombre = nombre;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultado = null;
        _error = 'No se pudo registrar: ${AuthService.mensajeDeError(e)}';
      });
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = claveFecha(DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          key: const Key('btn_escanear'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
          onPressed: _procesando ? null : _escanear,
          icon: const Icon(Icons.qr_code_scanner, size: 28),
          label: const Text('Escanear QR del trabajador',
              style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _procesando ? null : _ingresarManual,
          icon: const Icon(Icons.keyboard),
          label: const Text('Ingresar código manualmente'),
        ),
        const SizedBox(height: 16),
        if (_procesando) const LinearProgressIndicator(),
        if (_resultado != null)
          _TarjetaResultado(resultado: _resultado!, nombre: _nombre),
        if (_error != null)
          Card(
            color: const Color(0xFFFCE8E6),
            child: ListTile(
              leading: const Icon(Icons.error, color: Color(0xFFB3261E)),
              title: Text(_error!,
                  style: const TextStyle(color: Color(0xFF8C1D18))),
            ),
          ),
        const SizedBox(height: 8),
        Text('Abordajes de hoy ($hoy)',
            style: Theme.of(context).textTheme.titleMedium),
        StreamCacheado<List<Pasajero>>(
          clave: widget.ruta.id,
          crear: () => Repositorio.pasajeros(widget.ruta.id),
          builder: (context, sp) => StreamCacheado<List<Abordaje>>(
            clave: '${widget.ruta.id}-$hoy',
            crear: () => Repositorio.abordajes(widget.ruta.id, hoy),
            builder: (context, sa) {
              if (sp.hasError || sa.hasError) {
                return Text('Error: ${sp.error ?? sa.error}');
              }
              if (sp.data == null || sa.data == null) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return TarjetaAbordaje(
                ruta: widget.ruta,
                pasajeros: sp.data!,
                abordajes: sa.data!,
                inicialmenteAbierta: true,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TarjetaResultado extends StatelessWidget {
  const _TarjetaResultado({required this.resultado, this.nombre});
  final ResultadoAbordaje resultado;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final ok = resultado.exito;
    final fondo = ok ? const Color(0xFFDDF3E8) : const Color(0xFFFCE8E6);
    final texto = ok ? const Color(0xFF00573D) : const Color(0xFF8C1D18);
    return Card(
      key: Key('resultado_${resultado.name}'),
      color: fondo,
      child: ListTile(
        leading: Icon(ok ? Icons.check_circle : Icons.cancel,
            color: texto, size: 36),
        title: Text(resultado.mensaje,
            style: TextStyle(
                color: texto, fontSize: 18, fontWeight: FontWeight.w700)),
        subtitle: nombre == null
            ? null
            : Text(nombre!, style: TextStyle(color: texto, fontSize: 16)),
      ),
    );
  }
}

/// Cámara a pantalla completa; devuelve el texto del primer QR leído.
class _Escaner extends StatefulWidget {
  const _Escaner();

  @override
  State<_Escaner> createState() => _EscanerState();
}

class _EscanerState extends State<_Escaner> {
  final _control = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _leido = false;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_leido) return;
    final texto = captura.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (texto == null) return;
    _leido = true;
    Navigator.pop(context, texto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _control,
            onDetect: _alDetectar,
            errorBuilder: (context, error) => MensajeVacio(
              icono: Icons.no_photography,
              titulo: 'No se pudo abrir la cámara',
              detalle:
                  'Revisa el permiso de cámara o usa «Ingresar código manualmente».\n(${error.errorCode.name})',
            ),
          ),
          IgnorePointer(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 32,
            child: Text('Apunta al código del trabajador',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    shadows: [Shadow(blurRadius: 6)])),
          ),
        ],
      ),
    );
  }
}
