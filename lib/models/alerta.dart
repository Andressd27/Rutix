import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../core/rol.dart';

/// Alerta de emergencia: `alertas/{id}`. La envía un trabajador o un
/// conductor y la atiende un administrador.
class Alerta {
  const Alerta({
    required this.id,
    required this.uid,
    required this.nombre,
    required this.rol,
    required this.rutaNombre,
    required this.atendida,
    this.creada,
    this.ubicacion,
    this.atendidaPor,
    this.atendidaEn,
  });

  final String id;
  final String uid;
  final String nombre;
  final Rol rol;
  final String rutaNombre;
  final DateTime? creada;
  final LatLng? ubicacion;
  final bool atendida;
  final String? atendidaPor;
  final DateTime? atendidaEn;

  factory Alerta.desdeMapa(String id, Map<String, dynamic> d) {
    final g = d['ubicacion'];
    return Alerta(
      id: id,
      uid: (d['uid'] as String?) ?? '',
      nombre: (d['nombre'] as String?) ?? '',
      rol: Rol.desde(d['rol'] as String?) ?? Rol.trabajador,
      rutaNombre: (d['rutaNombre'] as String?) ?? 'Sin ruta',
      creada: (d['creada'] as Timestamp?)?.toDate(),
      ubicacion: g is GeoPoint ? LatLng(g.latitude, g.longitude) : null,
      atendida: (d['atendida'] as bool?) ?? false,
      atendidaPor: d['atendidaPor'] as String?,
      atendidaEn: (d['atendidaEn'] as Timestamp?)?.toDate(),
    );
  }

  static String hora(DateTime? t) => t == null
      ? '--:--'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Más recientes primero; las que no tienen hora (recién creadas) van arriba.
List<Alerta> ordenarAlertas(Iterable<Alerta> alertas) => alertas.toList()
  ..sort((a, b) {
    final ta = a.creada, tb = b.creada;
    if (ta == null && tb == null) return 0;
    if (ta == null) return -1;
    if (tb == null) return 1;
    return tb.compareTo(ta);
  });

/// Evita alertas repetidas por toques seguidos: una por minuto por persona.
const esperaEntreAlertas = Duration(minutes: 1);

bool puedeEnviarAlerta(DateTime? ultimaEnviada, DateTime ahora) =>
    ultimaEnviada == null || ahora.difference(ultimaEnviada) >= esperaEntreAlertas;

/// Número de teléfono para marcar: solo dígitos y `+`.
String? limpiarTelefono(String? texto) {
  if (texto == null) return null;
  final t = texto.replaceAll(RegExp(r'[^0-9+]'), '');
  return t.length >= 3 ? t : null;
}
