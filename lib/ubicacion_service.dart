import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum EstadoUbicacion {
  cargando,
  activa,
  servicioApagado,
  permisoDenegado,
  permisoDenegadoSiempre,
  error,
}

/// Ubicación del usuario en tiempo real (permisos + stream del GPS).
class UbicacionService {
  UbicacionService._();
  static final UbicacionService instancia = UbicacionService._();

  final ValueNotifier<Position?> posicion = ValueNotifier<Position?>(null);
  final ValueNotifier<EstadoUbicacion> estado =
      ValueNotifier<EstadoUbicacion>(EstadoUbicacion.cargando);

  StreamSubscription<Position>? _sub;
  StreamSubscription<ServiceStatus>? _servicioSub;

  bool get activa => estado.value == EstadoUbicacion.activa;

  /// Verifica servicio y permisos; si todo está bien empieza a escuchar el GPS.
  Future<void> iniciar() async {
    estado.value = EstadoUbicacion.cargando;

    if (!kIsWeb) {
      _servicioSub ??= Geolocator.getServiceStatusStream().listen((s) {
        if (s == ServiceStatus.enabled && !activa) {
          iniciar();
        } else if (s == ServiceStatus.disabled) {
          _detener();
          estado.value = EstadoUbicacion.servicioApagado;
        }
      });
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        estado.value = EstadoUbicacion.servicioApagado;
        return;
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied) {
        estado.value = EstadoUbicacion.permisoDenegado;
        return;
      }
      if (permiso == LocationPermission.deniedForever) {
        estado.value = EstadoUbicacion.permisoDenegadoSiempre;
        return;
      }

      _detener();
      // Primera posición rápida para no esperar al primer evento del stream.
      final ultima = kIsWeb ? null : await Geolocator.getLastKnownPosition();
      if (ultima != null) posicion.value = ultima;

      _sub = Geolocator.getPositionStream(locationSettings: _ajustes())
          .listen(
        (p) {
          posicion.value = p;
          estado.value = EstadoUbicacion.activa;
        },
        onError: (_) => estado.value = EstadoUbicacion.error,
      );
      if (posicion.value != null) estado.value = EstadoUbicacion.activa;
    } catch (_) {
      estado.value = EstadoUbicacion.error;
    }
  }

  /// Abre los ajustes adecuados según el problema actual.
  Future<void> abrirAjustes() async {
    // En web no hay ajustes del sistema: se vuelve a pedir el permiso.
    if (kIsWeb) return iniciar();
    if (estado.value == EstadoUbicacion.servicioApagado) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  LocationSettings _ajustes() {
    if (kIsWeb) {
      return const LocationSettings(accuracy: LocationAccuracy.high);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
          intervalDuration: const Duration(seconds: 2),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
          activityType: ActivityType.automotiveNavigation,
          pauseLocationUpdatesAutomatically: false,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        );
    }
  }

  void _detener() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    _detener();
    _servicioSub?.cancel();
    _servicioSub = null;
  }
}
