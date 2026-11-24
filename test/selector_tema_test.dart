import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rutix/services/tema_service.dart';
import 'package:rutix/widgets/comunes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El usuario puede elegir manualmente modo claro u oscuro y la elección
/// se conserva al volver a abrir la app.
void main() {
  test('el modo se guarda y se lee con el mismo texto', () {
    for (final m in ThemeMode.values) {
      expect(modoDesdeTexto(textoDeModo(m)), m);
    }
    expect(modoDesdeTexto(null), ThemeMode.system,
        reason: 'la primera vez sigue al teléfono');
    expect(modoDesdeTexto('otro'), ThemeMode.system);
  });

  test('la elección se conserva al volver a abrir la app', () async {
    SharedPreferences.setMockInitialValues({});
    final s = TemaService.instancia;
    await s.cambiar(ThemeMode.dark);
    s.modo.value = ThemeMode.system; // simula reiniciar la app
    await s.cargar();
    expect(s.modo.value, ThemeMode.dark);
  });

  testWidgets('el selector de Perfil cambia el modo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = TemaService.instancia..modo.value = ThemeMode.system;
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SelectorTema())));

    await tester.tap(find.text('Oscuro'));
    await tester.pump();
    expect(s.modo.value, ThemeMode.dark);

    await tester.tap(find.text('Claro'));
    await tester.pump();
    expect(s.modo.value, ThemeMode.light);

    final p = await SharedPreferences.getInstance();
    expect(p.getString('modo_tema'), 'claro');
  });
}
