import 'package:latlong2/latlong.dart';

/// Formato "encoded polyline" de Google, que también usa OSRM.
/// OSRM lo devuelve con precisión 6 (`geometries=polyline6`): ocupa ~10 veces
/// menos que una lista de coordenadas y cabe holgado en un documento de Firestore.
///
/// Importante: solo usa aritmética (`*`, `~/`, `%`), nunca operadores de bits.
/// En la web, Dart se compila a JavaScript y ahí `~`, `<<` y `|` trabajan con
/// enteros de 32 bits **sin signo**: las longitudes negativas de Colombia
/// (-73°) se decodificaban mal y el trazado desaparecía del mapa.
class Polilinea {
  Polilinea._();

  static List<LatLng> decodificar(String texto, {int precision = 6}) {
    final factor = _factor(precision);
    final puntos = <LatLng>[];
    var i = 0, lat = 0, lng = 0;
    while (i < texto.length) {
      for (var eje = 0; eje < 2; eje++) {
        var resultado = 0, multiplicador = 1, b = 0;
        do {
          b = texto.codeUnitAt(i++) - 63;
          resultado += (b % 32) * multiplicador; // 5 bits por carácter
          multiplicador *= 32;
        } while (b >= 32);
        // El bit más bajo indica el signo (codificación "zigzag").
        final delta = resultado.isOdd ? -((resultado + 1) ~/ 2) : resultado ~/ 2;
        if (eje == 0) {
          lat += delta;
        } else {
          lng += delta;
        }
      }
      puntos.add(LatLng(lat / factor, lng / factor));
    }
    return puntos;
  }

  static String codificar(List<LatLng> puntos, {int precision = 6}) {
    final factor = _factor(precision);
    final salida = StringBuffer();
    var latPrevia = 0, lngPrevia = 0;
    for (final p in puntos) {
      final lat = (p.latitude * factor).round();
      final lng = (p.longitude * factor).round();
      _valor(lat - latPrevia, salida);
      _valor(lng - lngPrevia, salida);
      latPrevia = lat;
      lngPrevia = lng;
    }
    return salida.toString();
  }

  static void _valor(int v, StringBuffer salida) {
    var x = v < 0 ? -2 * v - 1 : 2 * v;
    while (x >= 32) {
      salida.writeCharCode(32 + (x % 32) + 63);
      x ~/= 32;
    }
    salida.writeCharCode(x + 63);
  }

  static int _factor(int precision) {
    var f = 1;
    for (var i = 0; i < precision; i++) {
      f *= 10;
    }
    return f;
  }
}
