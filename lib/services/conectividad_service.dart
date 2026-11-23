import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Estado de la conexión a internet (RNF-02). Firestore reconecta y reanuda
/// sus streams por sí solo; este servicio solo sirve para avisar al usuario.
class ConectividadService {
  ConectividadService._();
  static final ConectividadService instancia = ConectividadService._();

  final ValueNotifier<bool> enLinea = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> iniciar() async {
    if (_sub != null) return;
    final c = Connectivity();
    try {
      _actualizar(await c.checkConnectivity());
    } catch (_) {}
    _sub = c.onConnectivityChanged.listen(_actualizar);
  }

  void _actualizar(List<ConnectivityResult> r) {
    enLinea.value = r.any((x) => x != ConnectivityResult.none);
  }
}
