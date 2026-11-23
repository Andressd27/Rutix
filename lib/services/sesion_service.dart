import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/usuario.dart';
import 'auth_service.dart';

sealed class EstadoSesion {
  const EstadoSesion();
}

class SesionCargando extends EstadoSesion {
  const SesionCargando();
}

class SinSesion extends EstadoSesion {
  const SinSesion();
}

/// Hay usuario en Firebase Auth pero su perfil no existe o no tiene un rol válido.
class PerfilInvalido extends EstadoSesion {
  final String mensaje;
  const PerfilInvalido(this.mensaje);
}

class ConSesion extends EstadoSesion {
  final Usuario usuario;
  const ConSesion(this.usuario);
}

/// Escucha la sesión de Firebase Auth y el perfil `usuarios/{uid}` en vivo.
/// Si el administrador cambia el rol o la ruta, la app se actualiza sola.
class SesionService {
  SesionService._();
  static final SesionService instancia = SesionService._();

  final ValueNotifier<EstadoSesion> estado =
      ValueNotifier<EstadoSesion>(const SesionCargando());

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _perfilSub;
  String? _creandoPerfil;

  Usuario? get usuario {
    final e = estado.value;
    return e is ConSesion ? e.usuario : null;
  }

  void iniciar() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen(_alCambiarAuth);
  }

  void _alCambiarAuth(User? user) {
    _perfilSub?.cancel();
    _perfilSub = null;
    if (user == null) {
      estado.value = const SinSesion();
      return;
    }
    estado.value = const SesionCargando();
    _perfilSub = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .snapshots()
        .listen(
      (doc) {
        final datos = doc.data();
        if (datos == null) {
          // Solo se decide con la respuesta del servidor, no con la caché.
          if (doc.metadata.isFromCache) return;
          // Cuenta sin perfil (recién registrada, o cuyo perfil no se guardó):
          // se crea como trabajador. El listener recibirá el documento nuevo.
          if (_creandoPerfil != user.uid) {
            _creandoPerfil = user.uid;
            AuthService.crearPerfil(user).catchError((Object e) {
              _creandoPerfil = null;
              estado.value =
                  PerfilInvalido('No se pudo crear tu perfil en Rutix: $e');
            });
          }
          return;
        }
        final u = Usuario.desdeMapa(user.uid, datos);
        estado.value = u == null
            ? const PerfilInvalido('Tu cuenta no tiene un rol válido.')
            : ConSesion(u);
      },
      onError: (Object e) {
        estado.value = PerfilInvalido('No se pudo leer tu perfil: $e');
      },
    );
  }
}
