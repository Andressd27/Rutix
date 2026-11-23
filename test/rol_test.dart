import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rutix/core/rol.dart';
import 'package:rutix/core/tema.dart';

/// Contraste WCAG 2.x entre dos colores.
double contraste(Color a, Color b) {
  double canal(double c) =>
      c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) =>
      0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  final la = lum(a), lb = lum(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  group('Roles (RF-01)', () {
    test('existen los tres roles', () {
      expect(Rol.values.map((r) => r.clave),
          containsAll(['trabajador', 'conductor', 'admin']));
    });

    test('cada rol tiene un color principal distinto', () {
      final colores = Rol.values.map((r) => r.color.toARGB32()).toSet();
      expect(colores.length, Rol.values.length);
    });

    test('el tema de la app usa el color del rol', () {
      for (final r in Rol.values) {
        expect(temaPara(r).colorScheme.primary, r.color);
      }
    });

    test('un rol desconocido no se acepta', () {
      expect(Rol.desde('superusuario'), isNull);
      expect(Rol.desde(null), isNull);
      expect(Rol.desde('conductor'), Rol.conductor);
    });
  });

  group('Accesibilidad (RNF-05)', () {
    test('texto blanco sobre el color de cada rol: contraste ≥ 4.5:1', () {
      for (final r in Rol.values) {
        final c = contraste(Colors.white, r.color);
        // ignore: avoid_print
        print('${r.etiqueta}: ${c.toStringAsFixed(2)}:1');
        expect(c, greaterThanOrEqualTo(4.5),
            reason: '${r.etiqueta}: ${c.toStringAsFixed(2)}:1');
      }
    });

    test('color de marca sobre fondo blanco: contraste ≥ 4.5:1', () {
      expect(contraste(colorMarca, Colors.white), greaterThanOrEqualTo(4.5));
    });

    test('los estilos de texto pequeños del tema miden al menos 14 sp', () {
      final t = temaPara(Rol.trabajador).textTheme;
      for (final s in [t.bodySmall, t.labelSmall, t.labelMedium, t.bodyMedium]) {
        expect(s!.fontSize, greaterThanOrEqualTo(14));
      }
    });
  });
}
