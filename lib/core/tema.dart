import 'package:material_ui/material_ui.dart';

import 'rol.dart';

/// Color neutro para las pantallas sin sesión (login y registro).
const colorMarca = Color(0xFF007A55);
const colorMarcaOscuro = Color(0xFF5FD6A4);

/// Color principal (botones, íconos, trazado) según el rol y el tema.
/// En modo oscuro se usa una versión clara del color del rol para mantener
/// contraste ≥ 4.5:1 sobre fondos oscuros (RNF-05).
Color colorPrincipal(Rol? rol, Brightness brillo) =>
    brillo == Brightness.dark
        ? (rol?.colorOscuro ?? colorMarcaOscuro)
        : (rol?.color ?? colorMarca);

/// Tema de la app según el rol con sesión iniciada (RF-01) y el modo claro u
/// oscuro del teléfono. La barra superior usa siempre el color fuerte del rol
/// con texto blanco, así el rol se reconoce igual en los dos modos.
ThemeData temaPara(Rol? rol, {Brightness brillo = Brightness.light}) {
  final oscuro = brillo == Brightness.dark;
  final principal = colorPrincipal(rol, brillo);
  final esquema = ColorScheme.fromSeed(
    seedColor: rol?.color ?? colorMarca,
    brightness: brillo,
    primary: principal,
    onPrimary: oscuro ? Colors.black : Colors.white,
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
      backgroundColor: rol?.color,
      foregroundColor: rol == null ? null : Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: principal.withValues(alpha: oscuro ? 0.28 : 0.18),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 14)),
    ),
  );
}

/// Rojo de acciones peligrosas (finalizar, eliminar, emergencia) con texto
/// blanco: contraste 6.5:1 en los dos modos.
const colorPeligro = Color(0xFFB3261E);
