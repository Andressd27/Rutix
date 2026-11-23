import 'package:material_ui/material_ui.dart';

/// Roles del sistema (RF-01). Cada rol tiene su propio color, ícono y nombre
/// para que siempre quede claro con qué tipo de cuenta se está trabajando.
enum Rol {
  trabajador(
    etiqueta: 'Trabajador',
    descripcion: 'Consulta tu ruta y la llegada del vehículo',
    color: Color(0xFF007A55), // verde · contraste 5.36:1 con blanco
    icono: Icons.badge,
  ),
  conductor(
    etiqueta: 'Conductor',
    descripcion: 'Inicia el recorrido y comparte la ubicación',
    color: Color(0xFF1D4ED8), // azul · contraste 6.70:1 con blanco
    icono: Icons.airline_seat_recline_normal,
  ),
  admin(
    etiqueta: 'Administrador',
    descripcion: 'Gestiona rutas, usuarios y asignaciones',
    color: Color(0xFF6D28D9), // morado · contraste 7.10:1 con blanco
    icono: Icons.admin_panel_settings,
  );

  const Rol({
    required this.etiqueta,
    required this.descripcion,
    required this.color,
    required this.icono,
  });

  final String etiqueta;
  final String descripcion;
  final Color color;
  final IconData icono;

  /// Nombre guardado en Firestore (`usuarios/{uid}.rol`).
  String get clave => name;

  static Rol? desde(String? valor) {
    for (final r in Rol.values) {
      if (r.name == valor) return r;
    }
    return null;
  }
}
