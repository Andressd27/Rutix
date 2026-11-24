import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../core/abordaje.dart';
import '../core/gestion_rutas.dart';
import '../core/rol.dart';
import '../data/datos_ejemplo.dart';
import '../models/abordaje.dart';
import '../models/alerta.dart';
import '../models/recorrido.dart';
import '../models/ruta.dart';
import '../models/usuario.dart';
import '../models/vehiculo.dart';
import 'osrm_service.dart';

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
    await completarCaminos();
  }

  /// Crea o edita una ruta (RF-07, solo admin). Devuelve su id.
  ///
  /// [origen] dice, para cada parada nueva, qué posición tenía antes (o `null`
  /// si es nueva). Con eso se corrige la parada de los trabajadores asignados
  /// cuando se reordenan o eliminan paradas. Si cambió el recorrido, se borra
  /// el camino por calles anterior y se recalcula con OSRM.
  static Future<String> guardarRuta({
    Ruta? anterior,
    required String nombre,
    required String turno,
    required String placa,
    required List<Parada> paradas,
    required List<int?> origen,
  }) async {
    final ref = anterior == null ? _rutas.doc() : _rutas.doc(anterior.id);
    List<(double, double)> coords(List<Parada> ps) =>
        [for (final p in ps) (p.punto.latitude, p.punto.longitude)];
    final cambio = anterior == null ||
        cambioElRecorrido(coords(anterior.paradas), coords(paradas));

    final lote = _db.batch();
    lote.set(
      ref,
      {
        'nombre': nombre.trim(),
        'turno': turno,
        'placa': placa,
        'paradas': paradas.map((p) => p.aMapa()).toList(),
        if (anterior == null) ...{
          'conductorUid': null,
          'conductorNombre': 'Sin asignar',
        },
        if (cambio) ...{
          'caminoPolilinea': null,
          'distanciaMetros': null,
          'duracionSegundos': null,
        },
      },
      SetOptions(merge: true),
    );

    // Los trabajadores guardan su parada por posición: se traduce a la nueva.
    if (anterior != null) {
      final pasajeros = await _pasajeros(anterior.id)
          .get(const GetOptions(source: Source.server));
      for (final d in pasajeros.docs) {
        final antes = (d.data()['paradaIdx'] as num?)?.toInt();
        final despues = nuevaPosicion(origen, antes);
        if (despues != antes) {
          lote.update(d.reference, {'paradaIdx': despues});
          lote.update(_usuarios.doc(d.id), {'paradaIdx': despues});
        }
      }
    }
    await lote.commit();

    if (cambio && paradas.length >= 2) {
      try {
        await calcularCamino(Ruta(
          id: ref.id,
          nombre: nombre,
          turno: turno,
          placa: placa,
          paradas: paradas,
        ));
      } catch (_) {
        // Sin conexión u OSRM caído: queda con líneas rectas y se reintenta
        // la próxima vez que el admin abra la app.
      }
    }
    return ref.id;
  }

  /// Elimina una ruta (solo admin): sus trabajadores y su conductor quedan sin
  /// ruta y se borra su recorrido en vivo. El historial de abordajes se conserva.
  static Future<void> eliminarRuta(Ruta ruta) async {
    final pasajeros =
        await _pasajeros(ruta.id).get(const GetOptions(source: Source.server));
    final lote = _db.batch();
    for (final d in pasajeros.docs) {
      lote.update(_usuarios.doc(d.id),
          {'rutaId': null, 'paradaIdx': null, 'codigoQr': null});
      lote.delete(d.reference);
    }
    if (ruta.conductorUid != null) {
      lote.update(_usuarios.doc(ruta.conductorUid), {'rutaId': null});
    }
    lote.delete(_recorridos.doc(ruta.id));
    lote.delete(_rutas.doc(ruta.id));
    await lote.commit();
  }

  // ---------------- Vehículos (RF-07) ----------------

  static CollectionReference<Map<String, dynamic>> get _vehiculos =>
      _db.collection('vehiculos');

  static Stream<List<Vehiculo>> vehiculos() => _vehiculos.snapshots().map((q) =>
      q.docs.map((d) => Vehiculo.desdeMapa(d.id, d.data())).toList()
        ..sort((a, b) => a.placa.compareTo(b.placa)));

  /// Crea o actualiza un vehículo. La placa es su identificador.
  static Future<void> guardarVehiculo(Vehiculo v) =>
      _vehiculos.doc(normalizarPlaca(v.placa)).set(v.aMapa());

  static Future<bool> existeVehiculo(String placa) async =>
      (await _vehiculos.doc(normalizarPlaca(placa)).get()).exists;

  static Future<void> eliminarVehiculo(String placa) =>
      _vehiculos.doc(placa).delete();

  // ---------------- Emergencias ----------------

  static CollectionReference<Map<String, dynamic>> get _alertas =>
      _db.collection('alertas');
  static DocumentReference<Map<String, dynamic>> get _empresa =>
      _db.collection('config').doc('empresa');

  /// Envía una alerta de emergencia con la ubicación del teléfono, si se tiene.
  static Future<void> enviarAlerta({
    required Usuario usuario,
    required String rutaNombre,
    LatLng? ubicacion,
  }) =>
      _alertas.add({
        'uid': usuario.uid,
        'nombre': usuario.nombre,
        'rol': usuario.rol.clave,
        'rutaId': usuario.rutaId,
        'rutaNombre': rutaNombre,
        'ubicacion': ubicacion == null
            ? null
            : GeoPoint(ubicacion.latitude, ubicacion.longitude),
        'creada': FieldValue.serverTimestamp(),
        'atendida': false,
      });

  /// Últimas 50 alertas (solo administrador).
  static Stream<List<Alerta>> alertas() => _alertas
      .orderBy('creada', descending: true)
      .limit(50)
      .snapshots()
      .map((q) => ordenarAlertas(
          q.docs.map((d) => Alerta.desdeMapa(d.id, d.data()))));

  /// Alertas enviadas por un usuario (para que vea si ya las atendieron).
  static Stream<List<Alerta>> misAlertas(String uid) => _alertas
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((q) => ordenarAlertas(
          q.docs.map((d) => Alerta.desdeMapa(d.id, d.data()))));

  static Future<void> atenderAlerta(String id, Usuario admin) =>
      _alertas.doc(id).update({
        'atendida': true,
        'atendidaPor': admin.nombre,
        'atendidaEn': FieldValue.serverTimestamp(),
      });

  /// Teléfono de la empresa para emergencias (`config/empresa.telefono`).
  static Stream<String?> telefonoEmpresa() => _empresa
      .snapshots()
      .map((d) => d.data()?['telefono'] as String?);

  static Future<void> guardarTelefonoEmpresa(String telefono) =>
      _empresa.set({'telefono': telefono.trim()}, SetOptions(merge: true));

  // ---------------- Camino por calles (OSRM) ----------------

  /// Calcula con OSRM el camino por calles de la ruta y lo guarda (solo admin).
  static Future<void> calcularCamino(Ruta ruta) async {
    final t = await OsrmService.calcular(ruta.trazado);
    await _rutas.doc(ruta.id).update({
      'caminoPolilinea': t.polilinea,
      'distanciaMetros': t.distanciaMetros,
      'duracionSegundos': t.duracionSegundos,
      'caminoCalculado': FieldValue.serverTimestamp(),
    });
  }

  /// Calcula el camino de las rutas que aún no lo tienen. Respeta el límite
  /// del servidor público de OSRM (1 consulta por segundo).
  /// Devuelve cuántas rutas quedaron con camino nuevo.
  static Future<int> completarCaminos() async {
    final q = await _rutas.get(const GetOptions(source: Source.server));
    final pendientes = q.docs
        .map((d) => Ruta.desdeMapa(d.id, d.data()))
        .where((r) => !r.tieneCamino && r.paradas.length >= 2)
        .toList();
    var listos = 0;
    for (final r in pendientes) {
      if (listos > 0) await Future<void>.delayed(const Duration(milliseconds: 1100));
      try {
        await calcularCamino(r);
        listos++;
      } catch (_) {
        // Sin conexión u OSRM caído: la ruta sigue con líneas rectas.
      }
    }
    return listos;
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
    final esPasajero = rol == Rol.trabajador && rutaId != null;

    // Token del QR (RF-05): se conserva si sigue en la misma ruta; si cambia
    // de ruta se genera uno nuevo y el QR anterior deja de servir.
    final token = (esPasajero &&
            usuario.esTrabajador &&
            usuario.rutaId == rutaId &&
            usuario.codigoQr != null)
        ? usuario.codigoQr!
        : CodigoQr.nuevoToken();

    lote.update(_usuarios.doc(usuario.uid), {
      'rol': rol.clave,
      'rutaId': rutaId,
      'paradaIdx': rol == Rol.trabajador ? paradaIdx : null,
      'codigoQr': esPasajero ? token : null,
    });

    // Lista de pasajeros de la ruta: base del QR y del resumen "X de Y".
    if (usuario.esTrabajador &&
        usuario.tieneRuta &&
        (!esPasajero || rutaId != usuario.rutaId)) {
      lote.delete(_pasajeros(usuario.rutaId!).doc(usuario.uid));
    }
    if (esPasajero) {
      lote.set(_pasajeros(rutaId).doc(usuario.uid), {
        'nombre': usuario.nombre,
        'paradaIdx': paradaIdx,
        'token': token,
      });
    }

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

  /// Lectura única desde el servidor (nunca desde la caché local).
  static Future<List<Usuario>> usuariosDelServidor() async {
    final q = await _usuarios.get(const GetOptions(source: Source.server));
    return q.docs
        .map((d) => Usuario.desdeMapa(d.id, d.data()))
        .whereType<Usuario>()
        .toList();
  }

  /// Trabajadores con ruta asignada que todavía no tienen código QR
  /// (por ejemplo, los asignados antes de que existiera el abordaje por QR).
  static List<Usuario> sinCodigoQr(List<Usuario> usuarios) => usuarios
      .where((u) => u.esTrabajador && u.tieneRuta && u.codigoQr == null)
      .toList();

  /// Genera el código QR que les falta a esos trabajadores, conservando su
  /// ruta y parada. Lo ejecuta la app del administrador automáticamente.
  static Future<int> repararCodigosQr(List<Usuario> usuarios) async {
    final pendientes = sinCodigoQr(usuarios);
    for (final u in pendientes) {
      await asignar(
        usuario: u,
        rol: Rol.trabajador,
        rutaId: u.rutaId,
        paradaIdx: u.paradaIdx,
      );
    }
    return pendientes.length;
  }

  // ---------------- Pasajeros y abordajes (RF-05, RF-06) ----------------

  static CollectionReference<Map<String, dynamic>> _pasajeros(String rutaId) =>
      _rutas.doc(rutaId).collection('pasajeros');
  static CollectionReference<Map<String, dynamic>> _abordajes(String rutaId) =>
      _rutas.doc(rutaId).collection('abordajes');

  /// Trabajadores asignados a la ruta (admin y conductor de la ruta).
  static Stream<List<Pasajero>> pasajeros(String rutaId) =>
      _pasajeros(rutaId).snapshots().map((q) =>
          q.docs.map((d) => Pasajero.desdeMapa(d.id, d.data())).toList()
            ..sort((a, b) => a.nombre.compareTo(b.nombre)));

  /// Abordajes de una ruta en una fecha (`aaaa-mm-dd`).
  static Stream<List<Abordaje>> abordajes(String rutaId, String fecha) =>
      _abordajes(rutaId).where('fecha', isEqualTo: fecha).snapshots().map(
          (q) => q.docs.map((d) => Abordaje.desdeMapa(rutaId, d.data())).toList()
            ..sort((a, b) => (b.hora ?? DateTime.now())
                .compareTo(a.hora ?? DateTime.now())));

  /// Abordaje de un trabajador en una fecha (lo puede leer el propio trabajador).
  static Stream<Abordaje?> abordajeDe(String rutaId, String fecha, String uid) =>
      _abordajes(rutaId).doc(idAbordaje(fecha, uid)).snapshots().map((d) =>
          d.data() == null ? null : Abordaje.desdeMapa(rutaId, d.data()!));

  /// El conductor escanea un QR y se registra el abordaje (RF-05).
  /// Devuelve el resultado y, si se conoce, el nombre del trabajador.
  static Future<(ResultadoAbordaje, String?)> registrarAbordaje({
    required String rutaId,
    required Usuario conductor,
    required String? textoQr,
  }) async {
    final codigo = CodigoQr.leer(textoQr);
    if (codigo == null) return (ResultadoAbordaje.invalido, null);

    final fecha = claveFecha(DateTime.now());
    final refPasajero = _pasajeros(rutaId).doc(codigo.uid);
    final refAbordaje = _abordajes(rutaId).doc(idAbordaje(fecha, codigo.uid));

    return _db.runTransaction((tx) async {
      final pasajero = await tx.get(refPasajero);
      final p = pasajero.data() == null
          ? null
          : Pasajero.desdeMapa(pasajero.id, pasajero.data()!);
      final previo = await tx.get(refAbordaje);
      final resultado = validarAbordaje(
        codigo: codigo,
        tokenAsignado: p?.token,
        yaAbordo: previo.exists,
      );
      if (resultado.exito) {
        tx.set(refAbordaje, {
          'uid': codigo.uid,
          'nombre': p!.nombre,
          'token': codigo.token,
          'fecha': fecha,
          'hora': FieldValue.serverTimestamp(),
          'conductorUid': conductor.uid,
          'conductorNombre': conductor.nombre,
        });
      }
      return (resultado, p?.nombre);
    });
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
