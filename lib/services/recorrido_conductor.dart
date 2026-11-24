import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../models/ruta.dart';
import '../models/usuario.dart';
import 'repositorio.dart';

enum FuenteRecorrido { ninguna, gps, simulacion }

/// Lado del conductor (RF-02): lee el GPS (o simula el recorrido) y publica la
/// posición en `recorridos/{rutaId}` mientras el recorrido esté activo.
class RecorridoConductor {
  RecorridoConductor._();
  static final RecorridoConductor instancia = RecorridoConductor._();

  /// Intervalo mínimo entre escrituras en Firestore (cuida la cuota gratuita).
  static const intervaloEscritura = Duration(seconds: 3);

  /// Aunque el vehículo esté detenido (sin nuevas lecturas del GPS), se vuelve
  /// a enviar la última posición con esta frecuencia. Así el trabajador puede
  /// distinguir "detenido" de "sin señal".
  static const intervaloSenal = Duration(seconds: 15);

  final ValueNotifier<FuenteRecorrido> fuente =
      ValueNotifier<FuenteRecorrido>(FuenteRecorrido.ninguna);
  final ValueNotifier<LatLng?> posicion = ValueNotifier<LatLng?>(null);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  StreamSubscription<Position>? _gpsSub;
  Timer? _simTimer;
  String? _rutaId;
  DateTime _ultimaEscritura = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _pendiente;
  Timer? _envioDiferido;
  Timer? _senal;

  bool get activo => fuente.value != FuenteRecorrido.ninguna;

  Future<bool> iniciarGps(Ruta ruta, Usuario conductor) async {
    error.value = null;
    if (!await Geolocator.isLocationServiceEnabled()) {
      error.value = 'Activa el GPS del teléfono.';
      return false;
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      error.value = 'Permiso de ubicación denegado.';
      return false;
    }
    if (!await _abrir(ruta, conductor, simulado: false)) return false;
    fuente.value = FuenteRecorrido.gps;
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: ajustesGps(defaultTargetPlatform, web: kIsWeb),
    ).listen(
      (p) => _publicar(LatLng(p.latitude, p.longitude)),
      onError: (Object e) => error.value = 'Error de GPS: $e',
    );
    return true;
  }

  /// Recorre la ruta automáticamente (para demostrar con dos teléfonos sin moverse).
  Future<bool> iniciarSimulacion(Ruta ruta, Usuario conductor) async {
    error.value = null;
    if (ruta.paradas.length < 2) {
      error.value = 'La ruta necesita al menos dos paradas.';
      return false;
    }
    if (!await _abrir(ruta, conductor, simulado: true)) return false;
    fuente.value = FuenteRecorrido.simulacion;
    // Recorre el camino por calles (o la línea recta si no hay) a velocidad
    // constante: unos 3 minutos para toda la ruta, con pasos de al menos 40 m.
    final camino = ruta.camino;
    final largo = Geo.longitud(camino, 0, camino.length - 1);
    final paso = largo / 180 < 40 ? 40.0 : largo / 180;
    final puntos = Geo.remuestrear(camino, paso);
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
    return true;
  }

  Future<void> finalizar() async {
    final rutaId = _rutaId;
    _detenerFuentes();
    if (rutaId == null) return;
    _rutaId = null;
    try {
      await Repositorio.finalizarRecorrido(rutaId);
    } catch (e) {
      error.value = 'No se pudo finalizar en el servidor: $e';
    }
  }

  Future<bool> _abrir(Ruta ruta, Usuario conductor,
      {required bool simulado}) async {
    _detenerFuentes();
    try {
      await Repositorio.iniciarRecorrido(
          rutaId: ruta.id, conductor: conductor, simulado: simulado);
    } catch (e) {
      error.value = 'No se pudo iniciar el recorrido: $e';
      return false;
    }
    _rutaId = ruta.id;
    _ultimaEscritura = DateTime.fromMillisecondsSinceEpoch(0);
    _senal = Timer.periodic(intervaloSenal, (_) {
      final p = posicion.value;
      final id = _rutaId;
      if (p != null && id != null &&
          DateTime.now().difference(_ultimaEscritura) >= intervaloSenal) {
        _escribir(id, p);
      }
    });
    return true;
  }

  void _publicar(LatLng p) {
    posicion.value = p;
    final rutaId = _rutaId;
    if (rutaId == null) return;
    final espera =
        intervaloEscritura - DateTime.now().difference(_ultimaEscritura);
    if (espera <= Duration.zero) {
      _escribir(rutaId, p);
    } else {
      // Se envía la última posición cuando se cumpla el intervalo.
      _pendiente = p;
      _envioDiferido ??= Timer(espera, () {
        _envioDiferido = null;
        final q = _pendiente;
        _pendiente = null;
        if (q != null && _rutaId == rutaId) _escribir(rutaId, q);
      });
    }
  }

  void _escribir(String rutaId, LatLng p) {
    _ultimaEscritura = DateTime.now();
    // Sin conexión, Firestore guarda la escritura y la envía al reconectar.
    Repositorio.publicarUbicacion(rutaId, p).catchError((Object e) {
      error.value = 'No se pudo enviar la ubicación: $e';
    });
  }

  void _detenerFuentes() {
    _gpsSub?.cancel();
    _gpsSub = null;
    _simTimer?.cancel();
    _simTimer = null;
    _envioDiferido?.cancel();
    _envioDiferido = null;
    _senal?.cancel();
    _senal = null;
    _pendiente = null;
    fuente.value = FuenteRecorrido.ninguna;
    posicion.value = null;
  }
}

/// Ajustes del GPS del conductor según la plataforma.
///
/// En Android se usa un **servicio en primer plano** (notificación fija
/// "Recorrido en curso"): como se inicia con la app abierta, Android sigue
/// entregando la ubicación con la pantalla apagada o con otra app delante,
/// sin pedir el permiso de "ubicación todo el tiempo".
/// En iOS se activan las actualizaciones en segundo plano (Info.plist →
/// UIBackgroundModes: location). En el navegador no hay segundo plano.
LocationSettings ajustesGps(TargetPlatform plataforma, {required bool web}) {
  if (web) {
    return const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 10);
  }
  switch (plataforma) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Rutix · Recorrido en curso',
          notificationText:
              'Compartiendo tu ubicación con los trabajadores de tu ruta.',
          notificationChannelName: 'Recorrido en curso',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    case TargetPlatform.iOS:
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    default:
      return const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10);
  }
}
