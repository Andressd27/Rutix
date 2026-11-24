import 'package:flutter_test/flutter_test.dart';
import 'package:rutix/core/gestion_rutas.dart';

/// RF-07 (propuesto): el administrador crea, edita y elimina rutas, paradas
/// y vehículos.
void main() {
  group('Validación de rutas', () {
    const dos = [
      ParadaBorrador(nombre: 'Parque', hora: '5:30 a. m.'),
      ParadaBorrador(nombre: 'Oficina', hora: '6:00 a. m.'),
    ];

    test('una ruta completa se puede guardar', () {
      expect(validarRuta(nombre: 'Ruta 06', turno: 'Noche', paradas: dos),
          isEmpty);
    });

    test('exige al menos dos paradas', () {
      final errores =
          validarRuta(nombre: 'Ruta 06', turno: 'Noche', paradas: [dos.first]);
      expect(errores.single, contains('al menos 2 paradas'));
    });

    test('exige nombre, turno válido y nombre y hora en cada parada', () {
      final errores = validarRuta(nombre: ' ', turno: 'Madrugada', paradas: const [
        ParadaBorrador(nombre: '', hora: '5:30 a. m.'),
        ParadaBorrador(nombre: 'Oficina', hora: ''),
      ]);
      expect(errores, hasLength(4));
    });
  });

  group('Horas de las paradas', () {
    test('formato de la app', () {
      expect(formatoHora(5, 30), '5:30 a. m.');
      expect(formatoHora(0, 5), '12:05 a. m.');
      expect(formatoHora(12, 0), '12:00 p. m.');
      expect(formatoHora(22, 15), '10:15 p. m.');
    });

    test('lee las horas guardadas (ida y vuelta)', () {
      for (var h = 0; h < 24; h++) {
        expect(leerHora(formatoHora(h, 45)), (h, 45));
      }
      expect(leerHora('22:10'), (22, 10));
      expect(leerHora('6:00 pm'), (18, 0));
    });

    test('rechaza horas inválidas', () {
      for (final t in ['', 'mañana', '25:00', '13:00 p. m.', '7:75']) {
        expect(leerHora(t), isNull, reason: t);
      }
    });
  });

  group('Vehículos', () {
    test('normaliza la placa', () {
      expect(normalizarPlaca('abc123'), 'ABC-123');
      expect(normalizarPlaca(' xyz-987 '), 'XYZ-987');
    });

    test('valida placa y capacidad', () {
      expect(validarVehiculo(placa: 'ABC-123', capacidad: 20), isEmpty);
      expect(validarVehiculo(placa: 'AB-12', capacidad: 20), hasLength(1));
      expect(validarVehiculo(placa: 'ABC123', capacidad: 0), hasLength(1));
      expect(validarVehiculo(placa: 'ABC123', capacidad: null), hasLength(1));
      expect(validarVehiculo(placa: 'ABC123', capacidad: 81), hasLength(1));
    });
  });

  group('Paradas de los trabajadores al editar la ruta', () {
    // Antes: [A, B, C, D]. Después: [A, C, nueva, B] (D eliminada).
    const origen = <int?>[0, 2, null, 1];

    test('cada trabajador conserva su misma parada aunque cambie de posición',
        () {
      expect(nuevaPosicion(origen, 0), 0); // A sigue primera
      expect(nuevaPosicion(origen, 1), 3); // B pasó al final
      expect(nuevaPosicion(origen, 2), 1); // C subió
    });

    test('si se elimina su parada queda sin parada', () {
      expect(nuevaPosicion(origen, 3), isNull); // D se eliminó
      expect(nuevaPosicion(origen, null), isNull);
    });

    test('solo se recalcula el trazado si cambian ubicaciones u orden', () {
      const a = [(7.0, -73.0), (7.1, -73.1)];
      expect(cambioElRecorrido(a, a), isFalse);
      expect(cambioElRecorrido(a, a.reversed.toList()), isTrue);
      expect(cambioElRecorrido(a, [...a, (7.2, -73.2)]), isTrue);
      expect(cambioElRecorrido(a, const [(7.0, -73.0), (7.1, -73.11)]), isTrue);
    });
  });
}
