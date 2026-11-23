import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/polilinea.dart';

/// Trazado por calles de una ruta, calculado con OSRM.
class TrazadoCalles {
  const TrazadoCalles({
    required this.polilinea,
    required this.distanciaMetros,
    required this.duracionSegundos,
  });

  /// Camino completo codificado en "polyline6".
  final String polilinea;
  final double distanciaMetros;
  final double duracionSegundos;

  List<LatLng> get puntos => Polilinea.decodificar(polilinea);
}

/// Cliente del servidor público de OSRM (Open Source Routing Machine), que usa
/// los mismos datos de OpenStreetMap que el mapa. Es gratuito y no pide clave,
/// pero es un servidor de demostración (máximo 1 consulta por segundo), así que
/// cada ruta se calcula **una sola vez** y se guarda en Firestore.
class OsrmService {
  OsrmService._();

  static const _servidor = 'https://router.project-osrm.org';

  /// Camino para ir en carro pasando por las paradas en orden.
  /// Lanza una excepción si el servicio no responde o no encuentra ruta.
  static Future<TrazadoCalles> calcular(List<LatLng> paradas,
      {http.Client? cliente}) async {
    if (paradas.length < 2) {
      throw ArgumentError('Se necesitan al menos dos paradas.');
    }
    // OSRM recibe longitud,latitud.
    final coordenadas = paradas
        .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');
    final url = Uri.parse('$_servidor/route/v1/driving/$coordenadas'
        '?overview=full&geometries=polyline6&steps=false');

    final c = cliente ?? http.Client();
    try {
      final r = await c.get(url).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) {
        throw Exception('OSRM respondió ${r.statusCode}');
      }
      return interpretar(r.body);
    } finally {
      if (cliente == null) c.close();
    }
  }

  /// Convierte la respuesta JSON de OSRM (separado para poder probarlo).
  static TrazadoCalles interpretar(String cuerpo) {
    final json = jsonDecode(cuerpo) as Map<String, dynamic>;
    if (json['code'] != 'Ok') {
      throw Exception('OSRM no encontró ruta: ${json['code']}');
    }
    final ruta = (json['routes'] as List).first as Map<String, dynamic>;
    return TrazadoCalles(
      polilinea: ruta['geometry'] as String,
      distanciaMetros: (ruta['distance'] as num).toDouble(),
      duracionSegundos: (ruta['duration'] as num).toDouble(),
    );
  }
}
