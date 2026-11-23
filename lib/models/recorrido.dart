import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Estado en vivo del recorrido de una ruta: `recorridos/{rutaId}` (RF-02).
/// Solo hay un documento por ruta; cada nuevo recorrido lo sobrescribe.
class Recorrido {
  final String rutaId;
  final bool activo;
  final String conductorUid;
  final String conductorNombre;
  final LatLng? ubicacion;
  final DateTime? inicio;
  final DateTime? actualizado;
  final bool simulado;

  const Recorrido({
    required this.rutaId,
    required this.activo,
    required this.conductorUid,
    required this.conductorNombre,
    this.ubicacion,
    this.inicio,
    this.actualizado,
    this.simulado = false,
  });

  /// Identifica este recorrido concreto (para avisar una sola vez por recorrido).
  String get idRecorrido =>
      '$rutaId-${inicio?.millisecondsSinceEpoch ?? 0}';

  factory Recorrido.desdeMapa(String rutaId, Map<String, dynamic> d) {
    final geo = d['ubicacion'];
    return Recorrido(
      rutaId: rutaId,
      activo: (d['activo'] as bool?) ?? false,
      conductorUid: (d['conductorUid'] as String?) ?? '',
      conductorNombre: (d['conductorNombre'] as String?) ?? '',
      ubicacion: geo is GeoPoint ? LatLng(geo.latitude, geo.longitude) : null,
      inicio: (d['inicio'] as Timestamp?)?.toDate(),
      actualizado: (d['actualizado'] as Timestamp?)?.toDate(),
      simulado: (d['simulado'] as bool?) ?? false,
    );
  }
}
