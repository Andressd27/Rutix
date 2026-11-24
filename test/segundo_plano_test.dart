import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rutix/core/senal.dart';
import 'package:rutix/services/recorrido_conductor.dart';
import 'package:rutix/widgets/comunes.dart';

/// RF-02: el recorrido sigue compartiendo la ubicación con la pantalla
/// apagada. RNF-02: el trabajador sabe si la posición está desactualizada.
void main() {
  group('GPS del conductor en segundo plano (RF-02)', () {
    test('Android usa un servicio en primer plano con notificación fija', () {
      final a = ajustesGps(TargetPlatform.android, web: false);
      expect(a, isA<AndroidSettings>());
      final n = (a as AndroidSettings).foregroundNotificationConfig!;
      expect(n.notificationTitle, contains('Recorrido en curso'));
      expect(n.setOngoing, isTrue, reason: 'el conductor no la puede descartar');
      expect(n.enableWakeLock, isTrue, reason: 'el teléfono no se duerme');
    });

    test('iOS permite actualizaciones en segundo plano', () {
      final a = ajustesGps(TargetPlatform.iOS, web: false) as AppleSettings;
      expect(a.allowBackgroundLocationUpdates, isTrue);
      expect(a.pauseLocationUpdatesAutomatically, isFalse);
    });

    test('en el navegador no se intenta un servicio en segundo plano', () {
      final a = ajustesGps(TargetPlatform.android, web: true);
      expect(a, isNot(isA<AndroidSettings>()));
    });

    test('el manifiesto de Android declara los permisos del servicio', () {
      final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      for (final p in [
        'FOREGROUND_SERVICE',
        'FOREGROUND_SERVICE_LOCATION',
        'WAKE_LOCK',
        'POST_NOTIFICATIONS',
      ]) {
        expect(m, contains('android.permission.$p'), reason: p);
      }
      // No se pide "ubicación todo el tiempo": no hace falta con el servicio
      // en primer plano y Google Play la restringe.
      expect(m, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    });

    test('iOS declara el modo de ubicación en segundo plano', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>UIBackgroundModes</key>'));
      expect(plist, contains('<string>location</string>'));
    });

    test('aunque el bus esté detenido, la señal se reenvía antes de que el '
        'trabajador la vea demorada', () {
      expect(RecorridoConductor.intervaloSenal * 3,
          lessThanOrEqualTo(limiteSenalBuena));
    });
  });

  group('Antigüedad de la señal (RNF-02)', () {
    test('hasta 45 s es buena', () {
      expect(estadoSenal(const Duration(seconds: 10)).nivel, NivelSenal.buena);
      expect(estadoSenal(const Duration(seconds: 45)).nivel, NivelSenal.buena);
      expect(estadoSenal(const Duration(seconds: 10)).texto,
          'Última señal hace 10 s');
    });

    test('entre 45 s y 2 min está demorada', () {
      final e = estadoSenal(const Duration(seconds: 90));
      expect(e.nivel, NivelSenal.demorada);
      expect(e.texto, 'Última señal hace 1 min');
    });

    test('después de 2 min se avisa que no hay señal', () {
      final e = estadoSenal(const Duration(minutes: 3));
      expect(e.nivel, NivelSenal.perdida);
      expect(e.texto, contains('Sin señal del vehículo hace 3 min'));
    });

    test('tolera relojes desfasados entre teléfonos', () {
      expect(estadoSenal(const Duration(seconds: -4)).nivel, NivelSenal.buena);
    });

    testWidgets('el indicador cambia de nivel con el tiempo', (tester) async {
      Future<void> mostrar(Duration hace) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: IndicadorSenal(ultima: DateTime.now().subtract(hace))),
          ));
      await mostrar(const Duration(seconds: 5));
      expect(find.byKey(const Key('senal_buena')), findsOneWidget);
      await mostrar(const Duration(minutes: 5));
      expect(find.byKey(const Key('senal_perdida')), findsOneWidget);
      expect(find.textContaining('Sin señal'), findsOneWidget);
    });
  });
}
