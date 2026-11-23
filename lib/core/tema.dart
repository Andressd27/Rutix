import 'package:material_ui/material_ui.dart';

import 'rol.dart';

/// Color neutro para las pantallas sin sesión (login y registro).
const colorMarca = Color(0xFF007A55);

/// Tema de la app según el rol con sesión iniciada (RF-01).
/// La barra superior se pinta con el color del rol para distinguirlo a simple vista.
ThemeData temaPara(Rol? rol) {
  final color = rol?.color ?? colorMarca;
  final esquema = ColorScheme.fromSeed(
    seedColor: color,
    primary: color,
    onPrimary: Colors.white,
  );
  // Tamaño mínimo de texto: 14 sp (RNF-05).
  final base = ThemeData(colorScheme: esquema, useMaterial3: true);
  final texto = base.textTheme.copyWith(
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14),
    bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 14),
    labelSmall: base.textTheme.labelSmall?.copyWith(fontSize: 14),
    labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 14),
  );
  return base.copyWith(
    textTheme: texto,
    appBarTheme: AppBarTheme(
      backgroundColor: rol == null ? null : color,
      foregroundColor: rol == null ? null : Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: color.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 14)),
    ),
  );
}
