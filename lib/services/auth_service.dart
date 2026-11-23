import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/rol.dart';
import 'recorrido_conductor.dart';

/// Inicio de sesión y registro con Firebase Auth (RNF-03: Firebase guarda las
/// contraseñas cifradas; nunca se almacenan en la app ni en Firestore).
class AuthService {
  AuthService._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Future<void> ingresar(String correo, String clave) async {
    await _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: clave,
    );
  }

  /// Toda cuenta nueva es de **trabajador**. Solo un administrador puede
  /// convertirla en conductor o administrador (lo imponen las reglas de Firestore).
  ///
  /// Aquí solo se crea la cuenta en Firebase Auth. El perfil en Firestore lo
  /// crea [SesionService] cuando ya escucha al usuario nuevo: si se escribiera
  /// aquí, Firestore podría enviarlo todavía sin sesión y el perfil se perdería.
  static Future<void> registrar({
    required String nombre,
    required String correo,
    required String clave,
  }) async {
    nombrePendiente = nombre.trim();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: clave,
    );
    await cred.user?.updateDisplayName(nombre.trim());
  }

  /// Nombre escrito en el registro, mientras se crea el perfil.
  static String? nombrePendiente;

  /// Crea el perfil `usuarios/{uid}` de una cuenta que aún no lo tiene.
  /// Siempre como trabajador y sin ruta (las reglas no permiten otra cosa).
  static Future<void> crearPerfil(User user) {
    final correo = (user.email ?? '').toLowerCase();
    final nombre = [nombrePendiente, user.displayName, correo.split('@').first]
        .firstWhere((n) => n != null && n.trim().isNotEmpty, orElse: () => '')!;
    nombrePendiente = null;
    return FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
      'nombre': nombre.trim(),
      'correo': correo,
      'rol': Rol.trabajador.clave,
      'rutaId': null,
      'paradaIdx': null,
      'creado': FieldValue.serverTimestamp(),
    });
  }

  /// Si es un conductor con recorrido activo, primero lo finaliza (mientras aún
  /// tiene permiso de escritura) para que su ubicación deje de compartirse.
  static Future<void> salir() async {
    await RecorridoConductor.instancia.finalizar();
    await _auth.signOut();
  }

  /// Traduce los códigos de error de Firebase a mensajes para el usuario.
  static String mensajeDeError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-login-credentials':
          return 'Correo o contraseña incorrectos.';
        case 'invalid-email':
          return 'El correo no es válido.';
        case 'email-already-in-use':
          return 'Ya existe una cuenta con ese correo.';
        case 'weak-password':
          return 'La contraseña debe tener al menos 6 caracteres.';
        case 'network-request-failed':
          return 'Sin conexión a internet. Inténtalo de nuevo.';
        case 'too-many-requests':
          return 'Demasiados intentos. Espera un momento.';
        case 'user-disabled':
          return 'Esta cuenta está deshabilitada.';
      }
      return 'No se pudo completar la operación (${e.code}).';
    }
    if (e is FirebaseException) {
      return 'Error del servidor (${e.code}).';
    }
    return 'Ocurrió un error inesperado.';
  }
}
