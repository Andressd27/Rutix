import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../models/recorrido.dart';
import '../models/ruta.dart';
import 'alerta_proximidad.dart';
import 'notificaciones_service.dart';
import 'repositorio.dart';

class Aviso {
  final String texto;
  final DateTime hora;
  Aviso(this.texto) : hora = DateTime.now();
}

/// Lado del trabajador (RF-03 y RF-04): escucha el recorrido de **su** ruta,
/// calcula cuánto falta por la carretera hasta su parada y lanza una
/// notificación local cuando el vehículo está a ≤ 1 km.
class SeguimientoTrabajador {
  SeguimientoTrabajador({required this.ruta, required this.paradaIdx})
      : _camino = ruta.tieneCamino
            ? ruta.camino
            : Geo.remuestrear(ruta.trazado, 50);

  final Ruta ruta;

  /// Parada de recogida del trabajador. `null` si aún no se la asignaron.
  final int? paradaIdx;

  /// Camino sobre el que se mide: por calles o, si no hay, la línea recta
  /// dividida en tramos de 50 m.
  final List<LatLng> _camino;

  final ValueNotifier<Recorrido?> recorrido = ValueNotifier<Recorrido?>(null);
  final ValueNotifier<List<Aviso>> avisos = ValueNotifier<List<Aviso>>([]);
  final _alerta = AlertaProximidad();
  final Set<String> _avisadoPaso = {};

  StreamSubscription<Recorrido?>? _sub;
  bool _estabaActivo = false;

  LatLng? get recogida =>
      paradaIdx == null ? null : ruta.paradas[paradaIdx!].punto;

  void iniciar() {
    NotificacionesService.instancia.pedirPermiso();
    _sub = Repositorio.recorrido(ruta.id).listen(
      _alCambiar,
      onError: (Object e) => debugPrint('Seguimiento: $e'),
    );
  }

  void detener() {
    _sub?.cancel();
    _sub = null;
  }

  Avance? _avance;
  String? _recorridoDePista;

  /// Avance del vehículo hacia la parada, si hay recorrido activo con ubicación.
  Avance? get avance => _avance;

  /// Recalcula el avance siguiendo al vehículo hacia adelante dentro del
  /// mismo recorrido (la ruta puede pasar dos veces por la misma vía).
  void _actualizarAvance(Recorrido? r) {
    final i = paradaIdx;
    if (r == null || !r.activo || r.ubicacion == null || i == null) {
      _avance = null;
      return;
    }
    final mismoRecorrido = _recorridoDePista == r.idRecorrido;
    _avance = Geo.avance(
      camino: _camino,
      paradas: ruta.trazado,
      paradaIdx: i,
      vehiculo: r.ubicacion!,
      pista: mismoRecorrido ? _avance?.indice : null,
    );
    _recorridoDePista = r.idRecorrido;
  }

  /// Metros por la carretera hasta la parada (`null` si no aplica o ya pasó).
  double? get metrosAlVehiculo => avance?.metros;

  /// Minutos estimados con la velocidad media de la ruta según OSRM.
  int? get minutosEstimados {
    final m = metrosAlVehiculo;
    return m == null
        ? null
        : Geo.minutosEstimados(m, velocidad: ruta.velocidadMedia);
  }

  void _alCambiar(Recorrido? r) {
    // El avance se calcula antes de notificar, para que la pantalla lo use.
    _actualizarAvance(r);
    recorrido.value = r;
    final activo = r != null && r.activo;
    if (activo && !_estabaActivo) _avisar('Tu ruta inició el recorrido');
    if (!activo && _estabaActivo) _avisar('El recorrido finalizó');
    _estabaActivo = activo;

    final a = avance;
    if (r == null || a == null) return;

    if (a.yaPaso) {
      if (_avisadoPaso.add(r.idRecorrido)) {
        _avisar('El vehículo ya pasó por tu parada');
      }
      return;
    }
    final m = a.metros!;
    if (_alerta.evaluar(idRecorrido: r.idRecorrido, metros: m)) {
      final min = minutosEstimados!;
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
