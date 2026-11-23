import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../core/polilinea.dart';

class Parada {
  final String nombre;
  final LatLng punto;
  final String hora;
  const Parada(this.nombre, this.punto, this.hora);

  factory Parada.desdeMapa(Map<String, dynamic> d) => Parada(
        (d['nombre'] as String?) ?? '',
        LatLng((d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()),
        (d['hora'] as String?) ?? '',
      );

  Map<String, dynamic> aMapa() => {
        'nombre': nombre,
        'lat': punto.latitude,
        'lng': punto.longitude,
        'hora': hora,
      };
}

/// Ruta guardada en `rutas/{id}`.
class Ruta {
  final String id;
  final String nombre;
  final String turno; // Mañana / Tarde / Noche
  final String placa;
  final String? conductorUid;
  final String conductorNombre;
  final List<Parada> paradas;

  /// Camino por calles calculado con OSRM ("polyline6"). `null` si aún no se
  /// calculó: en ese caso se usan líneas rectas entre paradas.
  final String? caminoPolilinea;
  final double? distanciaMetros;
  final double? duracionSegundos;

  const Ruta({
    required this.id,
    required this.nombre,
    required this.turno,
    required this.placa,
    required this.paradas,
    this.conductorUid,
    this.conductorNombre = 'Sin asignar',
    this.caminoPolilinea,
    this.distanciaMetros,
    this.duracionSegundos,
  });

  static final _caminos = Expando<List<LatLng>>();

  /// Paradas unidas en línea recta.
  List<LatLng> get trazado => paradas.map((p) => p.punto).toList();

  bool get tieneCamino =>
      caminoPolilinea != null && caminoPolilinea!.isNotEmpty;

  /// Línea a dibujar y a recorrer: por calles si existe; si no, recta.
  List<LatLng> get camino {
    if (!tieneCamino) return trazado;
    return _caminos[this] ??= Polilinea.decodificar(caminoPolilinea!);
  }

  /// Velocidad media del recorrido según OSRM (m/s), o 25 km/h por defecto.
  double get velocidadMedia {
    final d = distanciaMetros, t = duracionSegundos;
    if (d == null || t == null || t <= 0) return Geo.velocidadPorDefecto;
    return d / t;
  }

  factory Ruta.desdeMapa(String id, Map<String, dynamic> d) => Ruta(
        id: id,
        nombre: (d['nombre'] as String?) ?? id,
        turno: (d['turno'] as String?) ?? '',
        placa: (d['placa'] as String?) ?? '',
        conductorUid: d['conductorUid'] as String?,
        conductorNombre: (d['conductorNombre'] as String?) ?? 'Sin asignar',
        paradas: ((d['paradas'] as List?) ?? const [])
            .map((p) => Parada.desdeMapa(Map<String, dynamic>.from(p as Map)))
            .toList(),
        caminoPolilinea: d['caminoPolilinea'] as String?,
        distanciaMetros: (d['distanciaMetros'] as num?)?.toDouble(),
        duracionSegundos: (d['duracionSegundos'] as num?)?.toDouble(),
      );

  /// Datos editables de la ruta. El camino se guarda aparte
  /// (`Repositorio.guardarCamino`) para no borrarlo al editar.
  Map<String, dynamic> aMapa() => {
        'nombre': nombre,
        'turno': turno,
        'placa': placa,
        'conductorUid': conductorUid,
        'conductorNombre': conductorNombre,
        'paradas': paradas.map((p) => p.aMapa()).toList(),
      };
}
