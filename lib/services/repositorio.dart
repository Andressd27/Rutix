import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../core/rol.dart';
import '../data/datos_ejemplo.dart';
import '../models/recorrido.dart';
import '../models/ruta.dart';
import '../models/usuario.dart';

/// Acceso a Firestore. Colecciones:
/// - `usuarios/{uid}`      perfil y rol
/// - `rutas/{rutaId}`      ruta, vehículo, conductor y paradas
/// - `recorridos/{rutaId}` estado en vivo del recorrido de esa ruta
class Repositorio {
  Repositorio._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _usuarios =>
      _db.collection('usuarios');
  static CollectionReference<Map<String, dynamic>> get _rutas =>
      _db.collection('rutas');
  static CollectionReference<Map<String, dynamic>> get _recorridos =>
      _db.collection('recorridos');

  // ---------------- Rutas ----------------

  static Stream<Ruta?> ruta(String id) => _rutas.doc(id).snapshots().map(
      (d) => d.data() == null ? null : Ruta.desdeMapa(d.id, d.data()!));

  /// Solo el administrador puede listar todas las rutas (reglas de Firestore).
  static Stream<List<Ruta>> rutas() => _rutas.orderBy('nombre').snapshots().map(
      (q) => q.docs.map((d) => Ruta.desdeMapa(d.id, d.data())).toList());

  static Future<void> cargarRutasEjemplo() async {
    final lote = _db.batch();
    for (final r in rutasEjemplo) {
      lote.set(_rutas.doc(r.id), r.aMapa(), SetOptions(merge: true));
    }
    await lote.commit();
  }

  // ---------------- Usuarios ----------------

  static Stream<List<Usuario>> usuarios() =>
      _usuarios.orderBy('nombre').snapshots().map((q) => q.docs
          .map((d) => Usuario.desdeMapa(d.id, d.data()))
          .whereType<Usuario>()
          .toList());

  /// Cambia rol, ruta y parada de un usuario (solo administrador).
  /// Si queda como conductor de una ruta, la ruta guarda su nombre para que
  /// los trabajadores lo vean sin poder leer el perfil del conductor.
  static Future<void> asignar({
    required Usuario usuario,
    required Rol rol,
    String? rutaId,
    int? paradaIdx,
    String? conductorAnteriorUid,
  }) async {
    final lote = _db.batch();
    lote.update(_usuarios.doc(usuario.uid), {
      'rol': rol.clave,
      'rutaId': rutaId,
      'paradaIdx': rol == Rol.trabajador ? paradaIdx : null,
    });

    // Si dejaba de conducir otra ruta, se libera.
    if (usuario.esConductor &&
        usuario.tieneRuta &&
        (rol != Rol.conductor || rutaId != usuario.rutaId)) {
      lote.set(
        _rutas.doc(usuario.rutaId),
        {'conductorUid': null, 'conductorNombre': 'Sin asignar'},
        SetOptions(merge: true),
      );
    }
    if (rol == Rol.conductor && rutaId != null) {
      // Una ruta tiene un solo conductor: el anterior queda sin ruta.
      if (conductorAnteriorUid != null && conductorAnteriorUid != usuario.uid) {
        lote.update(_usuarios.doc(conductorAnteriorUid), {'rutaId': null});
      }
      lote.set(
        _rutas.doc(rutaId),
        {'conductorUid': usuario.uid, 'conductorNombre': usuario.nombre},
        SetOptions(merge: true),
      );
    }
    await lote.commit();
  }

  // ---------------- Recorridos (RF-02) ----------------

  static Stream<Recorrido?> recorrido(String rutaId) =>
      _recorridos.doc(rutaId).snapshots().map((d) =>
          d.data() == null ? null : Recorrido.desdeMapa(d.id, d.data()!));

  static Future<void> iniciarRecorrido({
    required String rutaId,
    required Usuario conductor,
    required bool simulado,
  }) {
    return _recorridos.doc(rutaId).set({
      'activo': true,
      'conductorUid': conductor.uid,
      'conductorNombre': conductor.nombre,
      'simulado': simulado,
      'ubicacion': null,
      'inicio': FieldValue.serverTimestamp(),
      'actualizado': FieldValue.serverTimestamp(),
      'fin': null,
    });
  }

  static Future<void> publicarUbicacion(String rutaId, LatLng p) {
    return _recorridos.doc(rutaId).update({
      'ubicacion': GeoPoint(p.latitude, p.longitude),
      'actualizado': FieldValue.serverTimestamp(),
    });
  }

  /// Al finalizar se borra la ubicación: solo se comparte con recorrido activo (RNF-04).
  static Future<void> finalizarRecorrido(String rutaId) {
    return _recorridos.doc(rutaId).update({
      'activo': false,
      'ubicacion': null,
      'fin': FieldValue.serverTimestamp(),
      'actualizado': FieldValue.serverTimestamp(),
    });
  }
}
