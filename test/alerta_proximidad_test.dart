import 'package:flutter_test/flutter_test.dart';
import 'package:rutix/core/geo.dart';
import 'package:rutix/services/alerta_proximidad.dart';

/// Criterio de aceptación de RF-04: a 2 km no llega notificación; a 1 km o
/// menos llega una sola.
void main() {
  group('AlertaProximidad (RF-04)', () {
    test('el umbral es de 1 km', () {
      expect(Geo.umbralAvisoMetros, 1000);
    });

    test('a 2 km no avisa', () {
      final a = AlertaProximidad();
      expect(a.evaluar(idRecorrido: 'R03-1', metros: 2000), isFalse);
    });

    test('a 1 km o menos avisa exactamente una vez', () {
      final a = AlertaProximidad();
      final resultados = <double>[2000, 1500, 1000, 800, 400, 50]
          .map((m) => a.evaluar(idRecorrido: 'R03-1', metros: m))
          .toList();
      expect(resultados.where((r) => r).length, 1);
      expect(resultados[2], isTrue, reason: 'a exactamente 1000 m sí avisa');
    });

    test('si el vehículo se aleja y vuelve, no repite el aviso', () {
      final a = AlertaProximidad();
      expect(a.evaluar(idRecorrido: 'R03-1', metros: 900), isTrue);
      expect(a.evaluar(idRecorrido: 'R03-1', metros: 1500), isFalse);
      expect(a.evaluar(idRecorrido: 'R03-1', metros: 700), isFalse);
    });

    test('un recorrido nuevo vuelve a avisar', () {
      final a = AlertaProximidad();
      expect(a.evaluar(idRecorrido: 'R03-1', metros: 900), isTrue);
      expect(a.evaluar(idRecorrido: 'R03-2', metros: 900), isTrue);
    });
  });
}
