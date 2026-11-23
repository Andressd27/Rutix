import 'package:latlong2/latlong.dart';

/// Utilidades geográficas puras (sin plugins), fáciles de probar.
class Geo {
  Geo._();

  /// Distancia a la que se avisa al trabajador (RF-04).
  static const double umbralAvisoMetros = 1000;

  /// Velocidad media supuesta para el tiempo estimado: 25 km/h ≈ 416 m/min.
  static const double metrosPorMinuto = 416;

  static const Distance _distancia = Distance();

  static double metros(LatLng a, LatLng b) => _distancia.distance(a, b);

  /// Minutos estimados de llegada (mínimo 1).
  static int minutosEstimados(double metros) {
    final m = (metros / metrosPorMinuto).ceil();
    return m < 1 ? 1 : m;
  }

  static int paradaMasCercana(LatLng p, List<LatLng> paradas) {
    var mejor = 0;
    var menor = double.infinity;
    for (var i = 0; i < paradas.length; i++) {
      final d = metros(p, paradas[i]);
      if (d < menor) {
        menor = d;
        mejor = i;
      }
    }
    return mejor;
  }

  /// Puntos intermedios entre paradas, para simular el recorrido.
  static List<LatLng> interpolar(List<LatLng> pts, int pasos) {
    if (pts.length < 2) return List.of(pts);
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
