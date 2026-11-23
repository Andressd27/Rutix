import 'package:latlong2/latlong.dart';

/// Resultado de comparar la posición del vehículo con una parada.
class Avance {
  const Avance({required this.metros, required this.yaPaso, this.indice = 0});

  /// Posición del vehículo dentro del camino. Se pasa como `pista` en la
  /// siguiente actualización para seguirlo hacia adelante.
  final int indice;

  /// Metros que faltan **por el camino** hasta la parada (`null` si ya pasó).
  final double? metros;

  /// `true` si el vehículo ya dejó atrás la parada.
  final bool yaPaso;
}

/// Utilidades geográficas puras (sin plugins), fáciles de probar.
class Geo {
  Geo._();

  /// Distancia a la que se avisa al trabajador (RF-04).
  static const double umbralAvisoMetros = 1000;

  /// Velocidad supuesta cuando no hay datos de OSRM: 25 km/h.
  static const double velocidadPorDefecto = 25000 / 3600;

  /// A menos de esta distancia de la parada se considera que el vehículo
  /// está llegando, no que ya pasó.
  static const double toleranciaParadaMetros = 60;

  static const Distance _distancia = Distance();

  static double metros(LatLng a, LatLng b) => _distancia.distance(a, b);

  /// Minutos estimados de llegada (mínimo 1).
  /// [velocidad] en metros por segundo (por defecto, 25 km/h).
  static int minutosEstimados(double metros,
      {double velocidad = velocidadPorDefecto}) {
    final v = velocidad > 0 ? velocidad : velocidadPorDefecto;
    final m = (metros / v / 60).ceil();
    return m < 1 ? 1 : m;
  }

  static int paradaMasCercana(LatLng p, List<LatLng> paradas) =>
      indiceMasCercano(paradas, p);

  /// Índice del punto de [camino] más cercano a [p], buscando desde [desde].
  static int indiceMasCercano(List<LatLng> camino, LatLng p, {int desde = 0}) {
    var mejor = desde;
    var menor = double.infinity;
    for (var i = desde; i < camino.length; i++) {
      final d = metros(p, camino[i]);
      if (d < menor) {
        menor = d;
        mejor = i;
      }
    }
    return mejor;
  }

  /// Posición de cada parada dentro del camino, respetando el orden de la ruta.
  static List<int> indicesDeParadas(List<LatLng> camino, List<LatLng> paradas) {
    final indices = <int>[];
    var desde = 0;
    for (final p in paradas) {
      final i = indiceMasCercano(camino, p, desde: desde);
      indices.add(i);
      desde = i;
    }
    return indices;
  }

  /// Longitud del camino entre los índices [desde] y [hasta].
  static double longitud(List<LatLng> camino, int desde, int hasta) {
    var total = 0.0;
    for (var i = desde; i < hasta && i + 1 < camino.length; i++) {
      total += metros(camino[i], camino[i + 1]);
    }
    return total;
  }

  /// Ubica [p] dentro del camino.
  ///
  /// Sin [pista] busca en todo el camino. Con [pista] (la posición anterior del
  /// vehículo) busca solo hacia adelante, en los siguientes ~3 km. Así no se
  /// confunde cuando la ruta pasa dos veces por la misma vía (ida y vuelta).
  /// Si el vehículo aparece lejos de ese tramo, vuelve a buscar en todo el camino.
  static int ubicarEnCamino(List<LatLng> camino, LatLng p, {int? pista}) {
    if (pista == null || camino.isEmpty) return indiceMasCercano(camino, p);
    final desde = (pista - 3).clamp(0, camino.length - 1);
    var mejor = desde;
    var menor = double.infinity;
    var recorrido = 0.0;
    for (var i = desde; i < camino.length; i++) {
      final d = metros(p, camino[i]);
      if (d < menor) {
        menor = d;
        mejor = i;
      }
      if (i > desde) recorrido += metros(camino[i - 1], camino[i]);
      if (recorrido > 3000) break;
    }
    return menor <= 150 ? mejor : indiceMasCercano(camino, p);
  }

  /// Cuánto le falta al vehículo, por el camino, para llegar a la parada
  /// número [paradaIdx], o si ya la pasó. [pista]: `indice` del avance anterior.
  static Avance avance({
    required List<LatLng> camino,
    required List<LatLng> paradas,
    required int paradaIdx,
    required LatLng vehiculo,
    int? pista,
  }) {
    final objetivo = indicesDeParadas(camino, paradas)[paradaIdx];
    final iv = ubicarEnCamino(camino, vehiculo, pista: pista);
    final alaParada = metros(vehiculo, paradas[paradaIdx]);
    if (iv > objetivo) {
      return alaParada <= toleranciaParadaMetros
          ? Avance(metros: alaParada, yaPaso: false, indice: iv)
          : Avance(metros: null, yaPaso: true, indice: iv);
    }
    final restante =
        metros(vehiculo, camino[iv]) + longitud(camino, iv, objetivo);
    return Avance(metros: restante, yaPaso: false, indice: iv);
  }

  /// Puntos separados cada [pasoMetros] a lo largo del camino (para simular a
  /// velocidad constante o para medir sobre líneas rectas).
  static List<LatLng> remuestrear(List<LatLng> camino, double pasoMetros) {
    if (camino.length < 2) return List.of(camino);
    final out = <LatLng>[camino.first];
    var sobrante = 0.0;
    for (var i = 0; i < camino.length - 1; i++) {
      final a = camino[i], b = camino[i + 1];
      final tramo = metros(a, b);
      if (tramo == 0) continue;
      var d = pasoMetros - sobrante;
      while (d <= tramo) {
        final t = d / tramo;
        out.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
        d += pasoMetros;
      }
      sobrante = tramo - (d - pasoMetros);
    }
    if (out.last != camino.last) out.add(camino.last);
    return out;
  }

  /// Puntos intermedios entre paradas, en línea recta.
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
