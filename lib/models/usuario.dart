import '../core/rol.dart';

/// Perfil guardado en `usuarios/{uid}`.
class Usuario {
  final String uid;
  final String nombre;
  final String correo;
  final Rol rol;

  /// Ruta asignada (trabajador y conductor). `null` = sin asignar.
  final String? rutaId;

  /// Índice de la parada de recogida dentro de la ruta (solo trabajador).
  final int? paradaIdx;

  /// Token de su QR de abordaje (solo trabajador con ruta; lo asigna el admin).
  final String? codigoQr;

  const Usuario({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.rutaId,
    this.paradaIdx,
    this.codigoQr,
  });

  bool get esTrabajador => rol == Rol.trabajador;
  bool get esConductor => rol == Rol.conductor;
  bool get esAdmin => rol == Rol.admin;
  bool get tieneRuta => rutaId != null && rutaId!.isNotEmpty;

  /// Devuelve `null` si el documento no tiene un rol válido.
  static Usuario? desdeMapa(String uid, Map<String, dynamic> d) {
    final rol = Rol.desde(d['rol'] as String?);
    if (rol == null) return null;
    return Usuario(
      uid: uid,
      nombre: (d['nombre'] as String?) ?? '',
      correo: (d['correo'] as String?) ?? '',
      rol: rol,
      rutaId: d['rutaId'] as String?,
      paradaIdx: (d['paradaIdx'] as num?)?.toInt(),
      codigoQr: d['codigoQr'] as String?,
    );
  }

  Map<String, dynamic> aMapa() => {
        'nombre': nombre,
        'correo': correo,
        'rol': rol.clave,
        'rutaId': rutaId,
        'paradaIdx': paradaIdx,
      };
}
