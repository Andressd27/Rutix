import 'package:material_ui/material_ui.dart';

import '../../core/rol.dart';
import '../../models/recorrido.dart';
import '../../models/ruta.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../services/repositorio.dart';
import '../../widgets/comunes.dart';
import 'resumen_abordajes.dart';

/// Interfaz del **administrador** (color morado): rutas, recorridos en vivo y
/// asignación de roles, rutas y paradas a los usuarios.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _pestana = 0;

  @override
  void initState() {
    super.initState();
    _revisarCodigosQr();
    _revisarCaminos();
  }

  /// Calcula el camino por calles de las rutas que aún no lo tienen.
  Future<void> _revisarCaminos() async {
    try {
      final n = await Repositorio.completarCaminos();
      if (mounted && n > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(n == 1
                ? 'Se calculó el trazado por calles de 1 ruta.'
                : 'Se calculó el trazado por calles de $n rutas.')));
      }
    } catch (e) {
      debugPrint('No se pudieron revisar los trazados: $e');
    }
  }

  /// Al abrir la app como administrador, genera el código QR que les falte a
  /// los trabajadores ya asignados. Así nadie tiene que volver a guardarlos.
  /// Si no hay conexión no hace nada; se reintenta la próxima vez que se abra.
  Future<void> _revisarCodigosQr() async {
    try {
      final usuarios = await Repositorio.usuariosDelServidor();
      final n = await Repositorio.repararCodigosQr(usuarios);
      if (mounted && n > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(n == 1
                ? 'Se generó el código QR de 1 trabajador.'
                : 'Se generaron los códigos QR de $n trabajadores.')));
      }
    } catch (e) {
      debugPrint('No se pudieron revisar los códigos QR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const titulos = ['Rutas', 'Abordajes', 'Usuarios', 'Perfil'];
    return Scaffold(
      appBar: BarraRol(usuario: widget.usuario, titulo: titulos[_pestana]),
      body: Column(
        children: [
          const BannerConexion(),
          Expanded(
            child: StreamCacheado<List<Ruta>>(
              clave: 'rutas',
              crear: () => Repositorio.rutas(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return MensajeVacio(
                      icono: Icons.error_outline,
                      titulo: 'No se pudieron cargar las rutas',
                      detalle: '${snap.error}');
                }
                final rutas = snap.data;
                if (rutas == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return IndexedStack(
                  index: _pestana,
                  children: [
                    _Rutas(rutas: rutas),
                    ResumenAbordajes(rutas: rutas),
                    _Usuarios(rutas: rutas),
                    PerfilPage(usuario: widget.usuario),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.alt_route), label: 'Rutas'),
          NavigationDestination(
              icon: Icon(Icons.qr_code_2), label: 'Abordajes'),
          NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Usuarios'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
      ),
    );
  }
}

class _Rutas extends StatelessWidget {
  const _Rutas({required this.rutas});
  final List<Ruta> rutas;

  Future<void> _cargarEjemplo(BuildContext context) async {
    try {
      await Repositorio.cargarRutasEjemplo();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudieron crear: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (rutas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MensajeVacio(
              icono: Icons.alt_route,
              titulo: 'Todavía no hay rutas',
              detalle: 'Carga las tres rutas de ejemplo para empezar a probar.',
            ),
            FilledButton.icon(
              onPressed: () => _cargarEjemplo(context),
              icon: const Icon(Icons.download),
              label: const Text('Cargar rutas de ejemplo'),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final r in rutas)
          Card(
            child: ExpansionTile(
              leading: _EstadoRecorrido(rutaId: r.id),
              title: Text('${r.nombre} · ${r.turno}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Conductor: ${r.conductorNombre} · ${r.placa}'),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _InfoCamino(ruta: r),
                ListaParadas(ruta: r),
              ],
            ),
          ),
      ],
    );
  }
}

/// Estado del trazado por calles de la ruta y botón para recalcularlo.
class _InfoCamino extends StatefulWidget {
  const _InfoCamino({required this.ruta});
  final Ruta ruta;

  @override
  State<_InfoCamino> createState() => _InfoCaminoState();
}

class _InfoCaminoState extends State<_InfoCamino> {
  bool _calculando = false;

  Future<void> _recalcular() async {
    setState(() => _calculando = true);
    try {
      await Repositorio.calcularCamino(widget.ruta);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo calcular el trazado: $e')));
      }
    } finally {
      if (mounted) setState(() => _calculando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ruta;
    final texto = r.tieneCamino
        ? 'Por calles · ${(r.distanciaMetros! / 1000).toStringAsFixed(1)} km · '
            '~${(r.duracionSegundos! / 60).round()} min'
        : 'Líneas rectas (sin trazado por calles)';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(r.tieneCamino ? Icons.route : Icons.timeline),
      title: Text(texto),
      trailing: _calculando
          ? const SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              tooltip: 'Recalcular trazado por calles',
              icon: const Icon(Icons.refresh),
              onPressed: _recalcular,
            ),
    );
  }
}

class _EstadoRecorrido extends StatelessWidget {
  const _EstadoRecorrido({required this.rutaId});
  final String rutaId;

  @override
  Widget build(BuildContext context) {
    return StreamCacheado<Recorrido?>(
      clave: rutaId,
      crear: () => Repositorio.recorrido(rutaId),
      builder: (context, snap) {
        final activo = snap.data?.activo ?? false;
        return Tooltip(
          message: activo ? 'Recorrido activo' : 'Sin recorrido',
          child: CircleAvatar(
            backgroundColor:
                activo ? const Color(0xFF007A55) : const Color(0xFF5F6368),
            child: Icon(activo ? Icons.directions_bus : Icons.pause,
                color: Colors.white),
          ),
        );
      },
    );
  }
}

class _Usuarios extends StatelessWidget {
  const _Usuarios({required this.rutas});
  final List<Ruta> rutas;

  @override
  Widget build(BuildContext context) {
    return StreamCacheado<List<Usuario>>(
      clave: 'usuarios',
      crear: () => Repositorio.usuarios(),
      builder: (context, snap) {
        if (snap.hasError) {
          return MensajeVacio(
              icono: Icons.error_outline,
              titulo: 'No se pudieron cargar los usuarios',
              detalle: '${snap.error}');
        }
        final usuarios = snap.data;
        if (usuarios == null) {
          return const Center(child: CircularProgressIndicator());
        }
        String rutaDe(Usuario u) {
          if (!u.tieneRuta) return 'Sin ruta';
          final r = rutas.where((r) => r.id == u.rutaId).firstOrNull;
          if (r == null) return 'Ruta ${u.rutaId} (no existe)';
          final i = u.paradaIdx;
          final parada = (u.esTrabajador && i != null && i < r.paradas.length)
              ? ' · ${r.paradas[i].nombre}'
              : '';
          return '${r.nombre}$parada';
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final rol in Rol.values) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(children: [
                  InsigniaRol(rol: rol),
                  const SizedBox(width: 8),
                  Text('${usuarios.where((u) => u.rol == rol).length}'),
                ]),
              ),
              for (final u in usuarios.where((u) => u.rol == rol))
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u.rol.color,
                      child: Icon(u.rol.icono, color: Colors.white),
                    ),
                    title: Text(u.nombre.isEmpty ? u.correo : u.nombre),
                    subtitle: Text('${u.correo}\n${rutaDe(u)}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.edit),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) =>
                          _DialogoAsignar(usuario: u, rutas: rutas),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _DialogoAsignar extends StatefulWidget {
  const _DialogoAsignar({required this.usuario, required this.rutas});
  final Usuario usuario;
  final List<Ruta> rutas;

  @override
  State<_DialogoAsignar> createState() => _DialogoAsignarState();
}

class _DialogoAsignarState extends State<_DialogoAsignar> {
  late Rol _rol = widget.usuario.rol;
  late String? _rutaId =
      widget.rutas.any((r) => r.id == widget.usuario.rutaId)
          ? widget.usuario.rutaId
          : null;
  late int? _parada = widget.usuario.paradaIdx;
  bool _guardando = false;

  Ruta? get _ruta => widget.rutas.where((r) => r.id == _rutaId).firstOrNull;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await Repositorio.asignar(
        usuario: widget.usuario,
        rol: _rol,
        rutaId: _rol == Rol.admin ? null : _rutaId,
        paradaIdx: _parada,
        conductorAnteriorUid: _ruta?.conductorUid,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AuthService.mensajeDeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ruta = _ruta;
    final paradas = ruta?.paradas ?? const [];
    if (_parada != null && _parada! >= paradas.length) _parada = null;

    return AlertDialog(
      title: Text(widget.usuario.nombre),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.usuario.correo),
            const SizedBox(height: 16),
            const Text('Rol', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<Rol>(
              segments: [
                for (final r in Rol.values)
                  ButtonSegment(
                      value: r, icon: Icon(r.icono), tooltip: r.etiqueta),
              ],
              selected: {_rol},
              onSelectionChanged: (s) => setState(() => _rol = s.first),
            ),
            const SizedBox(height: 4),
            Text(_rol.etiqueta,
                textAlign: TextAlign.center,
                style: TextStyle(color: _rol.color, fontWeight: FontWeight.w700)),
            if (_rol != Rol.admin) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _rutaId,
                decoration: const InputDecoration(
                    labelText: 'Ruta', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin ruta')),
                  for (final r in widget.rutas)
                    DropdownMenuItem(
                        value: r.id, child: Text('${r.nombre} · ${r.turno}')),
                ],
                onChanged: (v) => setState(() {
                  _rutaId = v;
                  _parada = null;
                }),
              ),
            ],
            if (_rol == Rol.trabajador && ruta != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                key: ValueKey(ruta.id),
                initialValue: _parada,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Parada de recogida',
                    border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin parada')),
                  for (var i = 0; i < paradas.length; i++)
                    DropdownMenuItem(
                        value: i,
                        child: Text('${i + 1}. ${paradas[i].nombre}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _parada = v),
              ),
            ],
            if (_rol == Rol.conductor && ruta != null &&
                ruta.conductorUid != null &&
                ruta.conductorUid != widget.usuario.uid) ...[
              const SizedBox(height: 8),
              Text(
                'Esta ruta ya la conduce ${ruta.conductorNombre}; quedará reemplazado.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _guardando ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: const Text('Guardar')),
      ],
    );
  }
}
