import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo claro / oscuro elegido por el usuario. Se guarda en el teléfono, así
/// se mantiene al cerrar la app y al cambiar de cuenta.
class TemaService {
  TemaService._();
  static final TemaService instancia = TemaService._();

  static const _clave = 'modo_tema';

  final ValueNotifier<ThemeMode> modo = ValueNotifier(ThemeMode.system);

  Future<void> cargar() async {
    try {
      final p = await SharedPreferences.getInstance();
      modo.value = modoDesdeTexto(p.getString(_clave));
    } catch (e) {
      debugPrint('No se pudo leer el modo de tema: $e');
    }
  }

  Future<void> cambiar(ThemeMode nuevo) async {
    modo.value = nuevo;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_clave, textoDeModo(nuevo));
    } catch (e) {
      debugPrint('No se pudo guardar el modo de tema: $e');
    }
  }
}

String textoDeModo(ThemeMode m) => switch (m) {
      ThemeMode.light => 'claro',
      ThemeMode.dark => 'oscuro',
      ThemeMode.system => 'sistema',
    };

ThemeMode modoDesdeTexto(String? t) => switch (t) {
      'claro' => ThemeMode.light,
      'oscuro' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
