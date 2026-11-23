import 'dart:math';

/// Contenido del QR de un trabajador (RF-05): `rutix:v1:{uid}:{token}`.
///
/// El `token` es aleatorio y lo genera el administrador al asignar la ruta.
/// Solo el conductor de esa ruta puede consultarlo, así que un QR inventado,
/// copiado de otra ruta o de una asignación anterior se rechaza.
class CodigoQr {
  const CodigoQr(this.uid, this.token);

  final String uid;
  final String token;

  static const prefijo = 'rutix:v1';
  static const _caracteres =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

  String get texto => '$prefijo:$uid:$token';

  /// Devuelve `null` si el texto no es un QR de Rutix bien formado.
  static CodigoQr? leer(String? texto) {
    if (texto == null) return null;
    final partes = texto.trim().split(':');
    if (partes.length != 4) return null;
    if ('${partes[0]}:${partes[1]}' != prefijo) return null;
    final uid = partes[2], token = partes[3];
    if (uid.isEmpty || token.length < 12) return null;
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(uid + token)) return null;
    return CodigoQr(uid, token);
  }

  static String nuevoToken([Random? aleatorio]) {
    final r = aleatorio ?? Random.secure();
    return List.generate(16, (_) => _caracteres[r.nextInt(_caracteres.length)])
        .join();
  }
}

enum ResultadoAbordaje {
  registrado('Abordaje registrado'),
  invalido('Código QR no válido'),
  otraRuta('Este trabajador no está asignado a tu ruta'),
  duplicado('Este trabajador ya abordó hoy');

  const ResultadoAbordaje(this.mensaje);
  final String mensaje;

  bool get exito => this == registrado;
}

/// Decide si un abordaje se acepta (RF-05). Es la misma regla que aplican
/// las reglas de seguridad de Firestore.
///
/// - [tokenAsignado]: token del pasajero en la ruta del conductor (`null` si
///   el trabajador no pertenece a esa ruta).
/// - [yaAbordo]: si ya existe un abordaje de ese trabajador hoy en la ruta.
ResultadoAbordaje validarAbordaje({
  required CodigoQr? codigo,
  required String? tokenAsignado,
  required bool yaAbordo,
}) {
  if (codigo == null) return ResultadoAbordaje.invalido;
  if (tokenAsignado == null) return ResultadoAbordaje.otraRuta;
  if (tokenAsignado != codigo.token) return ResultadoAbordaje.invalido;
  if (yaAbordo) return ResultadoAbordaje.duplicado;
  return ResultadoAbordaje.registrado;
}

/// Fecha del abordaje en formato `aaaa-mm-dd` (hora local del teléfono).
String claveFecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Id del documento `rutas/{rutaId}/abordajes/{fecha}_{uid}`: uno por
/// trabajador y día, así un segundo escaneo no puede crear otro registro.
String idAbordaje(String fecha, String uid) => '${fecha}_$uid';

/// Cuántos de los trabajadores asignados abordaron (RF-06). Los abordajes de
/// alguien que ya no está asignado a la ruta no cuentan.
int contarAbordaron(Iterable<String> asignados, Iterable<String> abordaron) {
  final subieron = abordaron.toSet();
  return asignados.toSet().where(subieron.contains).length;
}

/// Texto del resumen del administrador (RF-06).
String resumenAbordaje(int abordaron, int asignados) =>
    '$abordaron de $asignados';
