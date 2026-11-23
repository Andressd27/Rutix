import 'package:latlong2/latlong.dart';

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

  const Ruta({
    required this.id,
    required this.nombre,
    required this.turno,
    required this.placa,
    required this.paradas,
    this.conductorUid,
    this.conductorNombre = 'Sin asignar',
  });

  List<LatLng> get trazado => paradas.map((p) => p.punto).toList();

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
      );

  Map<String, dynamic> aMapa() => {
        'nombre': nombre,
        'turno': turno,
        'placa': placa,
        'conductorUid': conductorUid,
        'conductorNombre': conductorNombre,
        'paradas': paradas.map((p) => p.aMapa()).toList(),
      };
}
