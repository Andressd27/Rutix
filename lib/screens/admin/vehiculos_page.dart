import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/gestion_rutas.dart';
import '../../models/ruta.dart';
import '../../models/vehiculo.dart';
import '../../services/repositorio.dart';
import '../../widgets/comunes.dart';

/// Vehículos de la empresa (RF-07): placa, capacidad y descripción.
class VehiculosPage extends StatelessWidget {
  const VehiculosPage({super.key, required this.rutas});
  final List<Ruta> rutas;

  @override
  Widget build(BuildContext context) {
    return StreamCacheado<List<Vehiculo>>(
      clave: 'vehiculos',
      crear: Repositorio.vehiculos,
      builder: (context, snap) {
        if (snap.hasError) {
          return MensajeVacio(
              icono: Icons.error_outline,
              titulo: 'No se pudieron cargar los vehículos',
              detalle: '${snap.error}');
        }
        final vehiculos = snap.data;
        if (vehiculos == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: [
            if (vehiculos.isEmpty)
              const MensajeVacio(
                icono: Icons.directions_bus,
                titulo: 'Sin vehículos registrados',
                detalle: 'Agrega los vehículos para asignarlos a las rutas.',
              ),
            for (final v in vehiculos)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.directions_bus)),
                  title: Text(v.placa,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    '${v.capacidad} puestos',
                    if (v.descripcion.isNotEmpty) v.descripcion,
                    _usos(v.placa),
                  ].join(' · ')),
                  trailing: const Icon(Icons.edit),
                  onTap: () => mostrarDialogoVehiculo(context, vehiculo: v,
                      rutas: rutas),
                ),
              ),
          ],
        );
      },
    );
  }

  String _usos(String placa) {
    final usadas = rutas.where((r) => r.placa == placa).map((r) => r.nombre);
    return usadas.isEmpty ? 'Sin ruta' : usadas.join(', ');
  }
}

/// Crear (sin [vehiculo]) o editar un vehículo.
Future<void> mostrarDialogoVehiculo(BuildContext context,
    {Vehiculo? vehiculo, required List<Ruta> rutas}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DialogoVehiculo(vehiculo: vehiculo, rutas: rutas),
  );
}

class _DialogoVehiculo extends StatefulWidget {
  const _DialogoVehiculo({this.vehiculo, required this.rutas});
  final Vehiculo? vehiculo;
  final List<Ruta> rutas;

  @override
  State<_DialogoVehiculo> createState() => _DialogoVehiculoState();
}

class _DialogoVehiculoState extends State<_DialogoVehiculo> {
  late final _placa = TextEditingController(text: widget.vehiculo?.placa ?? '');
  late final _capacidad = TextEditingController(
      text: widget.vehiculo == null ? '' : '${widget.vehiculo!.capacidad}');
  late final _descripcion =
      TextEditingController(text: widget.vehiculo?.descripcion ?? '');
  List<String> _errores = const [];
  bool _guardando = false;

  bool get _nuevo => widget.vehiculo == null;

  @override
  void dispose() {
    _placa.dispose();
    _capacidad.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final capacidad = int.tryParse(_capacidad.text.trim());
    final errores =
        validarVehiculo(placa: _placa.text, capacidad: capacidad);
    if (errores.isNotEmpty) {
      setState(() => _errores = errores);
      return;
    }
    setState(() => _guardando = true);
    try {
      if (_nuevo && await Repositorio.existeVehiculo(_placa.text)) {
        setState(() {
          _guardando = false;
          _errores = [
            'Ya existe un vehículo con la placa ${normalizarPlaca(_placa.text)}.'
          ];
        });
        return;
      }
      await Repositorio.guardarVehiculo(Vehiculo(
        placa: normalizarPlaca(_placa.text),
        capacidad: capacidad!,
        descripcion: _descripcion.text.trim(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _guardando = false;
        _errores = ['No se pudo guardar: $e'];
      });
    }
  }

  Future<void> _eliminar() async {
    final placa = widget.vehiculo!.placa;
    final usadas = widget.rutas.where((r) => r.placa == placa).toList();
    if (usadas.isNotEmpty) {
      setState(() => _errores = [
            'No se puede eliminar: lo usa ${usadas.map((r) => r.nombre).join(', ')}. '
                'Cambia el vehículo de esa ruta primero.'
          ]);
      return;
    }
    setState(() => _guardando = true);
    try {
      await Repositorio.eliminarVehiculo(placa);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _guardando = false;
        _errores = ['No se pudo eliminar: $e'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_nuevo ? 'Nuevo vehículo' : 'Vehículo ${widget.vehiculo!.placa}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _placa,
              enabled: _nuevo, // la placa identifica al vehículo
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Placa',
                hintText: 'ABC-123',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _capacidad,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Capacidad (pasajeros)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descripcion,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ej.: Buseta blanca',
                border: OutlineInputBorder(),
              ),
            ),
            for (final e in _errores) ...[
              const SizedBox(height: 8),
              Text(e,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        if (!_nuevo)
          TextButton(
            onPressed: _guardando ? null : _eliminar,
            child: const Text('Eliminar'),
          ),
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
