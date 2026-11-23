import '../core/geo.dart';

/// Decide cuándo avisar al trabajador que el vehículo está cerca (RF-04).
///
/// Regla: se avisa **una sola vez por recorrido**, la primera vez que el
/// vehículo está a [umbralMetros] o menos de la parada de recogida.
class AlertaProximidad {
  AlertaProximidad({this.umbralMetros = Geo.umbralAvisoMetros});

  final double umbralMetros;
  final Set<String> _avisados = {};

  /// Devuelve `true` solo cuando hay que lanzar la notificación.
  bool evaluar({required String idRecorrido, required double metros}) {
    if (metros > umbralMetros) return false;
    return _avisados.add(idRecorrido);
  }

  bool yaAvisado(String idRecorrido) => _avisados.contains(idRecorrido);
}
