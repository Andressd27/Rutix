import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rutix/core/rol.dart';
import 'package:rutix/core/tema.dart';
import 'package:rutix/models/usuario.dart';
import 'package:rutix/screens/login_page.dart';
import 'package:rutix/widgets/comunes.dart';

Usuario _usuario(Rol rol) =>
    Usuario(uid: 'u', nombre: 'Prueba', correo: 'p@rutix.com', rol: rol);

void main() {
  testWidgets('Login: muestra el formulario y los tres roles', (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: temaPara(null), home: const LoginPage()));

    expect(find.text('Rutix'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    for (final r in Rol.values) {
      expect(find.text(r.etiqueta), findsOneWidget);
    }
  });

  testWidgets('Login: no muestra credenciales en pantalla (RNF-03)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    expect(find.textContaining('1234'), findsNothing);
  });

  testWidgets('Login: valida campos vacíos sin llamar al servidor',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
  });

  for (final rol in Rol.values) {
    testWidgets('La barra superior identifica el rol ${rol.etiqueta} (RF-01)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: temaPara(rol),
        home: Scaffold(
            appBar: BarraRol(usuario: _usuario(rol), titulo: 'Inicio')),
      ));
      expect(find.text(rol.etiqueta.toUpperCase()), findsOneWidget);
      expect(find.byIcon(rol.icono), findsOneWidget);
      final barra = tester.widget<Material>(find
          .descendant(of: find.byType(AppBar), matching: find.byType(Material))
          .first);
      expect(barra.color, rol.color);
    });
  }

  testWidgets('La tarjeta de bienvenida dice el tipo de sesión',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TarjetaRol(usuario: _usuario(Rol.conductor))),
    ));
    expect(find.text('Sesión de conductor'), findsOneWidget);
  });
}
