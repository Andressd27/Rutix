import 'package:flutter_test/flutter_test.dart';

import 'package:rutix/main.dart';

void main() {
  testWidgets('Muestra la pantalla de inicio de sesión', (tester) async {
    await tester.pumpWidget(const RutixApp());

    expect(find.text('Rutix'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
