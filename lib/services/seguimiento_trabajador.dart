import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../models/recorrido.dart';
import 'alerta_proximidad.dart';
import 'notificaciones_service.dart';
import 'repositorio.dart';

class Aviso {
  final String texto;
  final DateTime hora;
  Aviso(this.texto) : hora = DateTime.now();
}

/// Lado del trabajador (RF-03 y RF-04): escucha el recorrido de **su** ruta y
/// lanza una notificación local cuando el vehículo está a ≤ 1 km de su parada.
class SeguimientoTrabajador {
  SeguimientoTrabajador({required this.rutaId, required this.recogida});

  final String rutaId;
  /// Parada de recogida del trabajador. `null` si aún no se la asignaron.
  final LatLng? recogida;

  final ValueNotifier<Recorrido?> recorrido = ValueNotifier<Recorrido?>(null);
  final ValueNotifier<List<Aviso>> avisos = ValueNotifier<List<Aviso>>([]);
  final _alerta = AlertaProximidad();

  StreamSubscription<Recorrido?>? _sub;
  bool _estabaActivo = false;

  void iniciar() {
    NotificacionesService.instancia.pedirPermiso();
    _sub = Repositorio.recorrido(rutaId).listen(
      _alCambiar,
      onError: (Object e) => debugPrint('Seguimiento: $e'),
    );
  }

  void detener() {
    _sub?.cancel();
    _sub = null;
  }

  /// Distancia del vehículo a la parada de recogida, si hay recorrido activo.
  double? get metrosAlVehiculo {
    final r = recorrido.value;
    final destino = recogida;
    if (r == null || !r.activo || r.ubicacion == null || destino == null) {
      return null;
    }
    return Geo.metros(r.ubicacion!, destino);
  }

  void _alCambiar(Recorrido? r) {
    recorrido.value = r;
    final activo = r != null && r.activo;
    if (activo && !_estabaActivo) _avisar('Tu ruta inició el recorrido');
    if (!activo && _estabaActivo) _avisar('El recorrido finalizó');
    _estabaActivo = activo;

    final m = metrosAlVehiculo;
    if (r == null || m == null) return;
    if (_alerta.evaluar(idRecorrido: r.idRecorrido, metros: m)) {
      final min = Geo.minutosEstimados(m);
      _avisar('El vehículo está a ${m.round()} m de tu parada');
      NotificacionesService.instancia.mostrar(
        titulo: '¡Tu transporte está cerca!',
        cuerpo: 'Está a ${m.round()} m de tu parada · llega en ~$min min.',
      );
    }
  }

  void _avisar(String texto) {
    avisos.value = [Aviso(texto), ...avisos.value];
  }
}
