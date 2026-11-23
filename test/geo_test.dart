import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutix/core/geo.dart';

void main() {
  group('Geo (RF-03: tiempo estimado de llegada)', () {
    test('1 km de distancia ≈ 3 minutos a 25 km/h', () {
      expect(Geo.minutosEstimados(1000), 3);
    });

    test('el tiempo estimado nunca es menor a 1 minuto', () {
      expect(Geo.minutosEstimados(0), 1);
      expect(Geo.minutosEstimados(50), 1);
    });

    test('el tiempo estimado disminuye al acercarse', () {
      final distancias = <double>[5000, 3000, 1500, 800, 100];
      final minutos = distancias.map(Geo.minutosEstimados).toList();
      for (var i = 1; i < minutos.length; i++) {
        expect(minutos[i], lessThanOrEqualTo(minutos[i - 1]));
      }
      expect(minutos.first, greaterThan(minutos.last));
    });

    test('la distancia entre dos puntos conocidos es correcta (±1 %)', () {
      // 0.01° de latitud ≈ 1112 m
      final d = Geo.metros(const LatLng(7.0, -73.0), const LatLng(7.01, -73.0));
      expect(d, closeTo(1112, 12));
    });

    test('encuentra la parada más cercana', () {
      const paradas = [LatLng(7.0, -73.0), LatLng(7.1, -73.1), LatLng(7.2, -73.2)];
      expect(Geo.paradaMasCercana(const LatLng(7.09, -73.09), paradas), 1);
    });

    test('la simulación pasa por todas las paradas y termina en la última', () {
      const paradas = [LatLng(7.0, -73.0), LatLng(7.1, -73.1), LatLng(7.2, -73.2)];
      final puntos = Geo.interpolar(paradas, 10);
      expect(puntos.length, 21);
      expect(puntos.first, paradas.first);
      expect(puntos[10], paradas[1]);
      expect(puntos.last, paradas.last);
    });
  });
}
