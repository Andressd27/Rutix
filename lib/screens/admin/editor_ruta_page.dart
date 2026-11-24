import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/gestion_rutas.dart';
import '../../models/ruta.dart';
import '../../models/vehiculo.dart';
import '../../services/repositorio.dart';
import '../../widgets/comunes.dart';

/// Parada mientras se edita. [origen] es la posición que tenía en la ruta
/// guardada (`null` si se agregó ahora); sirve para no perder la parada de
/// los trabajadores al reordenar.
class _ParadaEditable {
  _ParadaEditable(this.nombre, this.punto, this.hora, this.origen);
  String nombre;
  LatLng punto;
  String hora;
  final int? origen;
}

/// Crear o editar una ruta (RF-07): nombre, turno, vehículo y paradas.
class EditorRutaPage extends StatefulWidget {
  const EditorRutaPage({super.key, this.ruta});

  /// `null` para crear una ruta nueva.
  final Ruta? ruta;

  @override
  State<EditorRutaPage> createState() => _EditorRutaPageState();
}

class _EditorRutaPageState extends State<EditorRutaPage> {
  late final _nombre = TextEditingController(text: widget.ruta?.nombre ?? '');
  late String _turno = widget.ruta?.turno ?? turnos.first;
  late String _placa = widget.ruta?.placa ?? '';
  late final List<_ParadaEditable> _paradas = [
    for (var i = 0; i < (widget.ruta?.paradas.length ?? 0); i++)
      _ParadaEditable(widget.ruta!.paradas[i].nombre,
          widget.ruta!.paradas[i].punto, widget.ruta!.paradas[i].hora, i),
  ];
  final _mapa = MapController();
  int? _moviendo; // parada que se reubicará con el próximo toque en el mapa
  bool _cambios = false;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  void _marcarCambio(VoidCallback cambio) => setState(() {
        cambio();
        _cambios = true;
      });

  String _horaSiguiente() {
    if (_paradas.isEmpty) return formatoHora(6, 0);
    final h = leerHora(_paradas.last.hora);
    if (h == null) return _paradas.last.hora;
    final total = h.$1 * 60 + h.$2 + 15;
    return formatoHora((total ~/ 60) % 24, total % 60);
  }

  void _tocarMapa(LatLng punto) {
    if (_moviendo != null) {
      final i = _moviendo!;
      _marcarCambio(() {
        _paradas[i].punto = punto;
        _moviendo = null;
      });
      return;
    }
    _marcarCambio(() => _paradas.add(_ParadaEditable(
        'Parada ${_paradas.length + 1}', punto, _horaSiguiente(), null)));
  }

  Future<void> _editarNombre(int i) async {
    final control = TextEditingController(text: _paradas[i].nombre);
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nombre de la parada ${i + 1}'),
        content: TextField(
          controller: control,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              hintText: 'Ej.: Parque principal', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, control.text),
              child: const Text('Aceptar')),
        ],
      ),
    );
    control.dispose();
    if (nombre != null && nombre.trim().isNotEmpty) {
      _marcarCambio(() => _paradas[i].nombre = nombre.trim());
    }
  }

  Future<void> _editarHora(int i) async {
    final actual = leerHora(_paradas[i].hora) ?? (6, 0);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: actual.$1, minute: actual.$2),
      helpText: 'Hora de la parada ${i + 1}',
    );
    if (t != null) {
      _marcarCambio(() => _paradas[i].hora = formatoHora(t.hour, t.minute));
    }
  }

  Future<void> _guardar() async {
    final errores = validarRuta(
      nombre: _nombre.text,
      turno: _turno,
      paradas: [
        for (final p in _paradas) ParadaBorrador(nombre: p.nombre, hora: p.hora)
      ],
    );
    if (errores.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Revisa la ruta'),
          content: Text(errores.map((e) => '• $e').join('\n')),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido')),
          ],
        ),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await Repositorio.guardarRuta(
        anterior: widget.ruta,
        nombre: _nombre.text,
        turno: _turno,
        placa: _placa,
        paradas: [for (final p in _paradas) Parada(p.nombre, p.punto, p.hora)],
        origen: [for (final p in _paradas) p.origen],
      );
      if (!mounted) return;
      _cambios = false;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  Future<bool> _confirmarSalir() async {
    if (!_cambios) return true;
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Se perderán los cambios de esta ruta.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir editando')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir')),
        ],
      ),
    );
    return salir ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final centro = _paradas.isNotEmpty
        ? _paradas.first.punto
        : const LatLng(7.1193, -73.1227); // Bucaramanga

    return PopScope(
      canPop: !_cambios,
      onPopInvokedWithResult: (salio, _) async {
        if (salio) return;
        if (await _confirmarSalir() && context.mounted) {
          _cambios = false;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.ruta == null ? 'Nueva ruta' : 'Editar ruta'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                key: const Key('btn_guardar_ruta'),
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _cambios = true,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la ruta',
                      hintText: 'Ej.: Ruta 06',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: [
                            for (final t in turnos)
                              ButtonSegment(value: t, label: Text(t)),
                          ],
                          selected: {_turno},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) =>
                              _marcarCambio(() => _turno = s.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamCacheado<List<Vehiculo>>(
                    clave: 'vehiculos',
                    crear: Repositorio.vehiculos,
                    builder: (context, snap) {
                      final vehiculos = snap.data ?? const <Vehiculo>[];
                      final placas = {
                        for (final v in vehiculos) v.placa,
                        if (_placa.isNotEmpty) _placa,
                      };
                      return DropdownButtonFormField<String>(
                        initialValue: _placa,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Vehículo',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Sin vehículo')),
                          for (final p in placas)
                            DropdownMenuItem(
                              value: p,
                              child: Text(
                                vehiculos
                                        .where((v) => v.placa == p)
                                        .firstOrNull
                                        ?.etiqueta ??
                                    p,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => _marcarCambio(() => _placa = v ?? ''),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapa,
                    options: MapOptions(
                      initialCenter: centro,
                      initialZoom: 13,
                      onTap: (_, punto) => _tocarMapa(punto),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'co.edu.uts.rutix',
                      ),
                      if (_paradas.length > 1)
                        PolylineLayer(polylines: [
                          Polyline(
                            points: [for (final p in _paradas) p.punto],
                            strokeWidth: 3,
                            color: color.withValues(alpha: 0.6),
                            pattern: StrokePattern.dashed(segments: const [10, 8]),
                          ),
                        ]),
                      MarkerLayer(markers: [
                        for (var i = 0; i < _paradas.length; i++)
                          Marker(
                            point: _paradas[i].punto,
                            width: 32,
                            height: 32,
                            child: CircleAvatar(
                              backgroundColor: _moviendo == i
                                  ? const Color(0xFFB3261E)
                                  : color,
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ]),
                    ],
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 8,
                    child: Card(
                      color: _moviendo != null
                          ? const Color(0xFFFCE8E6)
                          : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          _moviendo != null
                              ? 'Toca el mapa para mover la parada ${_moviendo! + 1}.'
                              : 'Toca el mapa para agregar una parada. '
                                  'El trazado por calles se calcula al guardar.',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: _paradas.isEmpty
                  ? const MensajeVacio(
                      icono: Icons.add_location_alt,
                      titulo: 'Sin paradas',
                      detalle: 'Toca el mapa en el orden en que el vehículo '
                          'recoge a los trabajadores.',
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _paradas.length,
                      onReorderItem: (desde, hasta) => _marcarCambio(() {
                        _paradas.insert(hasta, _paradas.removeAt(desde));
                        _moviendo = null;
                      }),
                      itemBuilder: (context, i) {
                        final p = _paradas[i];
                        return ListTile(
                          key: ObjectKey(p),
                          leading: CircleAvatar(
                            backgroundColor:
                                _moviendo == i ? const Color(0xFFB3261E) : color,
                            foregroundColor: Colors.white,
                            child: Text('${i + 1}'),
                          ),
                          title: InkWell(
                            onTap: () => _editarNombre(i),
                            child: Text(p.nombre),
                          ),
                          subtitle: InkWell(
                            onTap: () => _editarHora(i),
                            child: Row(children: [
                              const Icon(Icons.schedule, size: 16),
                              const SizedBox(width: 4),
                              Text(p.hora),
                            ]),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Mover en el mapa',
                                icon: Icon(_moviendo == i
                                    ? Icons.close
                                    : Icons.open_with),
                                onPressed: () => setState(() =>
                                    _moviendo = _moviendo == i ? null : i),
                              ),
                              IconButton(
                                tooltip: 'Eliminar parada',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _marcarCambio(() {
                                  _paradas.removeAt(i);
                                  _moviendo = null;
                                }),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
