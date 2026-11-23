import 'package:cloud_firestore/cloud_firestore.dart';

/// Trabajador asignado a una ruta: `rutas/{rutaId}/pasajeros/{uid}`.
/// Solo lo leen el administrador y el conductor de la ruta.
class Pasajero {
  final String uid;
  final String nombre;
  final int? paradaIdx;
  final String token;

  const Pasajero({
    required this.uid,
    required this.nombre,
    required this.token,
    this.paradaIdx,
  });

  factory Pasajero.desdeMapa(String uid, Map<String, dynamic> d) => Pasajero(
        uid: uid,
        nombre: (d['nombre'] as String?) ?? '',
        paradaIdx: (d['paradaIdx'] as num?)?.toInt(),
        token: (d['token'] as String?) ?? '',
      );
}

/// Registro de abordaje: `rutas/{rutaId}/abordajes/{fecha}_{uid}` (RF-05).
class Abordaje {
  final String rutaId;
  final String uid;
  final String nombre;
  final String fecha;
  final DateTime? hora;
  final String conductorNombre;

  const Abordaje({
    required this.rutaId,
    required this.uid,
    required this.nombre,
    required this.fecha,
    required this.conductorNombre,
    this.hora,
  });

  factory Abordaje.desdeMapa(String rutaId, Map<String, dynamic> d) => Abordaje(
        rutaId: rutaId,
        uid: (d['uid'] as String?) ?? '',
        nombre: (d['nombre'] as String?) ?? '',
        fecha: (d['fecha'] as String?) ?? '',
        hora: (d['hora'] as Timestamp?)?.toDate(),
        conductorNombre: (d['conductorNombre'] as String?) ?? '',
      );

  String get horaTexto {
    final h = hora;
    if (h == null) return '--:--';
    return '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
  }
}
