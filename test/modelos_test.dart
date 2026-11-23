import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutix/core/rol.dart';
import 'package:rutix/data/datos_ejemplo.dart';
import 'package:rutix/models/recorrido.dart';
import 'package:rutix/models/ruta.dart';
import 'package:rutix/models/usuario.dart';

void main() {
  group('Usuario', () {
    test('lee un perfil de trabajador', () {
      final u = Usuario.desdeMapa('abc', {
        'nombre': 'Ana',
        'correo': 'ana@rutix.com',
        'rol': 'trabajador',
        'rutaId': 'R03',
        'paradaIdx': 2,
      })!;
      expect(u.rol, Rol.trabajador);
      expect(u.esTrabajador, isTrue);
      expect(u.tieneRuta, isTrue);
      expect(u.paradaIdx, 2);
    });

    test('un perfil sin rol válido se rechaza', () {
      expect(Usuario.desdeMapa('x', {'nombre': 'X', 'rol': 'jefe'}), isNull);
    });

    test('sin ruta asignada', () {
      final u = Usuario.desdeMapa('x', {'rol': 'conductor', 'rutaId': null})!;
      expect(u.tieneRuta, isFalse);
    });
  });

  group('Ruta', () {
    test('se guarda y se lee igual en Firestore', () {
      final original = rutasEjemplo.first;
      final leida = Ruta.desdeMapa(original.id, original.aMapa());
      expect(leida.nombre, original.nombre);
      expect(leida.paradas.length, original.paradas.length);
      expect(leida.paradas[2].punto, original.paradas[2].punto);
      expect(leida.conductorNombre, 'Sin asignar');
    });

    test('las rutas de ejemplo tienen al menos dos paradas', () {
      for (final r in rutasEjemplo) {
        expect(r.paradas.length, greaterThanOrEqualTo(2));
      }
    });
  });

  group('Recorrido (RF-02)', () {
    test('lee la ubicación y el estado', () {
      final inicio = DateTime(2026, 11, 21, 18);
      final r = Recorrido.desdeMapa('R03', {
        'activo': true,
        'conductorUid': 'c1',
        'conductorNombre': 'Carlos',
        'ubicacion': const GeoPoint(7.1, -73.1),
        'inicio': Timestamp.fromDate(inicio),
      });
      expect(r.activo, isTrue);
      expect(r.ubicacion, const LatLng(7.1, -73.1));
      expect(r.idRecorrido, 'R03-${inicio.millisecondsSinceEpoch}');
    });

    test('un recorrido finalizado no tiene ubicación (RNF-04)', () {
      final r = Recorrido.desdeMapa('R03', {'activo': false, 'ubicacion': null});
      expect(r.activo, isFalse);
      expect(r.ubicacion, isNull);
    });
  });
}
