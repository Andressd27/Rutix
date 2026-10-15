import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'models.dart';

enum Fuente { ninguna, gps, simulacion }

/// Estado compartido del recorrido (sin base de datos: vive en memoria).
class TrackingService {
  TrackingService._();
  static final TrackingService instancia = TrackingService._();

  static const double umbralCercaniaMetros = 300;

  final ValueNotifier<LatLng?> vehiculo = ValueNotifier<LatLng?>(null);
  final ValueNotifier<Fuente> fuente = ValueNotifier<Fuente>(Fuente.ninguna);
  final ValueNotifier<List<Evento>> eventos = ValueNotifier<List<Evento>>([]);
  final ValueNotifier<String?> mensaje = ValueNotifier<String?>(null);

  StreamSubscription<Position>? _gpsSub;
  Timer? _simTimer;
  Ruta? rutaActiva;
  LatLng? _recogidaDemo;
  bool _alertado = false;

  bool get enRecorrido => fuente.value != Fuente.ninguna;

  // ---------- utilidades ----------
  static double metrosHasta(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);

  /// Estimación con velocidad media de 25 km/h (~416 m/min).
  static int minutosEstimados(double metros) {
    final m = (metros / 416).ceil();
    return m < 1 ? 1 : m;
  }

  static int paradaMasCercana(LatLng p, Ruta r) {
    var mejor = 0;
    var menor = double.infinity;
    for (var i = 0; i < r.paradas.length; i++) {
      final d = metrosHasta(p, r.paradas[i].punto);
      if (d < menor) {
        menor = d;
        mejor = i;
      }
    }
    return mejor;
  }

  void _registrar(String texto, IconData icono) {
    eventos.value = [Evento(texto, icono), ...eventos.value];
  }

  void _preparar(Ruta ruta) {
    _limpiar();
    rutaActiva = ruta;
    _alertado = false;
    final trabajadores =
        usuariosDemo.where((u) => u.rol == 'trabajador' && u.rutaId == ruta.id);
    _recogidaDemo =
        trabajadores.isEmpty ? null : ruta.paradas[trabajadores.first.paradaIdx].punto;
    _registrar('Ruta confirmada', Icons.check_circle);
  }

  void _publicar(LatLng p) {
    vehiculo.value = p;
    final recogida = _recogidaDemo;
    if (!_alertado && recogida != null &&
        metrosHasta(p, recogida) <= umbralCercaniaMetros) {
      _alertado = true;
      _registrar('Alerta de proximidad', Icons.notifications_active);
    }
  }

  void _limpiar() {
    _gpsSub?.cancel();
    _gpsSub = null;
    _simTimer?.cancel();
    _simTimer = null;
    fuente.value = Fuente.ninguna;
    vehiculo.value = null;
  }

  // ---------- conductor: GPS real ----------
  Future<bool> iniciarGps(Ruta ruta) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      mensaje.value = 'Activa el GPS del teléfono.';
      return false;
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      mensaje.value = 'Permiso de ubicación denegado.';
      return false;
    }
    _preparar(ruta);
    fuente.value = Fuente.gps;
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) => _publicar(LatLng(pos.latitude, pos.longitude)));
    return true;
  }

  // ---------- conductor: simulación (para la demo en un solo teléfono) ----------
  void iniciarSimulacion(Ruta ruta) {
    _preparar(ruta);
    fuente.value = Fuente.simulacion;
    final puntos = _interpolar(ruta.trazado, 40);
    var i = 0;
    _publicar(puntos.first);
    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      i++;
      if (i >= puntos.length) {
        finalizar();
        return;
      }
      _publicar(puntos[i]);
    });
  }

  void finalizar() {
    if (!enRecorrido) return;
    _limpiar();
    _registrar('Recorrido finalizado', Icons.flag);
  }

  List<LatLng> _interpolar(List<LatLng> pts, int pasos) {
    final out = <LatLng>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      for (var s = 0; s < pasos; s++) {
        final t = s / pasos;
        out.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }
    out.add(pts.last);
    return out;
  }
}
