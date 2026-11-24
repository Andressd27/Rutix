import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rutix/core/rol.dart';
import 'package:rutix/core/tema.dart';
import 'package:rutix/models/alerta.dart';
import 'package:rutix/models/usuario.dart';
import 'package:rutix/widgets/comunes.dart';

double contraste(Color a, Color b) {
  double canal(double c) =>
      c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) =>
      0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  final la = lum(a), lb = lum(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  group('Modo oscuro (RNF-05)', () {
    for (final rol in [null, ...Rol.values]) {
      final nombre = rol?.etiqueta ?? 'sin sesión';
      final t = temaPara(rol, brillo: Brightness.dark);
      final c = t.colorScheme;

      test('$nombre: el color principal se lee sobre el fondo (≥ 4.5:1)', () {
        for (final fondo in [c.surface, c.surfaceContainerHighest]) {
          expect(contraste(c.primary, fondo), greaterThanOrEqualTo(4.5),
              reason: '$nombre sobre $fondo');
        }
      });

      test('$nombre: el texto sobre los botones se lee (≥ 4.5:1)', () {
        expect(contraste(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
      });

      test('$nombre: el texto normal se lee sobre el fondo (≥ 4.5:1)', () {
        expect(contraste(c.onSurface, c.surface), greaterThanOrEqualTo(4.5));
      });
    }

    test('la barra superior conserva el color fuerte del rol en los dos modos',
        () {
      for (final rol in Rol.values) {
        final claro = temaPara(rol).appBarTheme;
        final oscuro = temaPara(rol, brillo: Brightness.dark).appBarTheme;
        expect(claro.backgroundColor, rol.color);
        expect(oscuro.backgroundColor, rol.color);
        expect(contraste(Colors.white, rol.color), greaterThanOrEqualTo(4.5));
      }
    });

    test('los tres roles siguen teniendo colores distintos en modo oscuro', () {
      final colores = Rol.values.map((r) => r.colorOscuro.toARGB32()).toSet();
      expect(colores.length, 3);
    });

    test('el rojo de peligro con texto blanco se lee (≥ 4.5:1)', () {
      expect(contraste(Colors.white, colorPeligro), greaterThanOrEqualTo(4.5));
    });

    test('la app sigue el modo del teléfono', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('darkTheme: temaPara('));
      expect(main, contains('themeMode: ThemeMode.system'));
    });
  });

  group('Alertas de emergencia', () {
    test('una alerta por minuto como máximo', () {
      final t = DateTime(2026, 11, 24, 22);
      expect(puedeEnviarAlerta(null, t), isTrue);
      expect(puedeEnviarAlerta(t, t.add(const Duration(seconds: 30))), isFalse);
      expect(puedeEnviarAlerta(t, t.add(const Duration(minutes: 1))), isTrue);
    });

    test('se leen desde Firestore con ubicación y estado', () {
      final a = Alerta.desdeMapa('a1', {
        'uid': 'u1',
        'nombre': 'Ana',
        'rol': 'trabajador',
        'rutaNombre': 'Ruta 03 · ABC-123',
        'ubicacion': const GeoPoint(7.1, -73.1),
        'creada': Timestamp.fromDate(DateTime(2026, 11, 24, 22, 5)),
        'atendida': false,
      });
      expect(a.rol, Rol.trabajador);
      expect(a.ubicacion, const LatLng(7.1, -73.1));
      expect(a.atendida, isFalse);
      expect(Alerta.hora(a.creada), '22:05');
    });

    test('las más recientes van primero (y las recién enviadas arriba)', () {
      Alerta a(String id, DateTime? t) => Alerta(
          id: id,
          uid: 'u',
          nombre: id,
          rol: Rol.trabajador,
          rutaNombre: 'R',
          atendida: false,
          creada: t);
      final lista = ordenarAlertas([
        a('vieja', DateTime(2026, 1, 1, 8)),
        a('nueva', DateTime(2026, 1, 1, 9)),
        a('enviando', null),
      ]);
      expect(lista.map((x) => x.id), ['enviando', 'nueva', 'vieja']);
    });

    test('el teléfono de la empresa se limpia para poder marcarlo', () {
      expect(limpiarTelefono('300 123 4567'), '3001234567');
      expect(limpiarTelefono('+57 (7) 634-0000'), '+5776340000');
      expect(limpiarTelefono(''), isNull);
      expect(limpiarTelefono(null), isNull);
    });

    Usuario usuario(Rol rol) =>
        Usuario(uid: 'u', nombre: 'Prueba', correo: 'p@rutix.com', rol: rol);

    for (final rol in Rol.values) {
      final debeTener = rol != Rol.admin;
      testWidgets(
          '${rol.etiqueta}: ${debeTener ? 'tiene' : 'no tiene'} botón SOS en la barra',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: temaPara(rol),
          home: Scaffold(
              appBar: BarraRol(usuario: usuario(rol), titulo: 'Inicio')),
        ));
        expect(find.byKey(const Key('btn_sos')),
            debeTener ? findsOneWidget : findsNothing);
      });
    }

    test('las reglas protegen las alertas', () {
      final reglas = File('firestore.rules').readAsStringSync();
      expect(reglas, contains('match /alertas/{id}'));
      expect(reglas, contains('request.resource.data.rol == perfil().rol'));
      expect(reglas, contains("hasOnly(['atendida', 'atendidaPor', 'atendidaEn'])"));
    });
  });
}
