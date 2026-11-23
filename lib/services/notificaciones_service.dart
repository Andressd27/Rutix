import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificaciones **locales**: las genera el propio teléfono del trabajador al
/// detectar que el vehículo está cerca. No necesitan servidor ni Cloud
/// Functions, así que funcionan con el plan gratuito (Spark) de Firebase.
class NotificacionesService {
  NotificacionesService._();
  static final NotificacionesService instancia = NotificacionesService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;

  static const _canal = AndroidNotificationDetails(
    'rutix_proximidad',
    'Llegada del transporte',
    channelDescription: 'Aviso cuando tu vehículo está cerca de tu parada',
    importance: Importance.max,
    priority: Priority.high,
  );

  Future<void> iniciar() async {
    if (_listo) return;
    try {
      _listo = await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
              ),
              web: WebInitializationSettings(),
            ),
          ) ??
          false;
    } catch (e) {
      debugPrint('Notificaciones no disponibles: $e');
      _listo = false;
    }
  }

  /// Pide permiso (Android 13+, iOS y navegador). Devuelve si quedó concedido.
  Future<bool> pedirPermiso() async {
    await iniciar();
    if (!_listo) return false;
    try {
      if (kIsWeb) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    WebFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                      AndroidFlutterLocalNotificationsPlugin>()
                  ?.requestNotificationsPermission() ??
              false;
        case TargetPlatform.iOS:
          return await _plugin
                  .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin>()
                  ?.requestPermissions(alert: true, sound: true) ??
              false;
        default:
          return true;
      }
    } catch (e) {
      debugPrint('No se pudo pedir permiso de notificaciones: $e');
      return false;
    }
  }

  Future<void> mostrar({required String titulo, required String cuerpo}) async {
    await iniciar();
    if (!_listo) return;
    try {
      await _plugin.show(
        id: 1,
        title: titulo,
        body: cuerpo,
        notificationDetails: const NotificationDetails(
          android: _canal,
          iOS: DarwinNotificationDetails(),
          web: WebNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo mostrar la notificación: $e');
    }
  }
}
