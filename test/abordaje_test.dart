import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutix/core/abordaje.dart';
import 'package:rutix/core/rol.dart';
import 'package:rutix/models/abordaje.dart';
import 'package:rutix/models/usuario.dart';
import 'package:rutix/services/repositorio.dart';
import 'package:rutix/models/ruta.dart';
import 'package:rutix/screens/admin/resumen_abordajes.dart';

void main() {
  group('Código QR (RF-05)', () {
    test('el QR generado se puede leer de vuelta', () {
      const c = CodigoQr('abc123XYZ', 'Kq7mT2pLx9WvRb4N');
      final leido = CodigoQr.leer(c.texto)!;
      expect(leido.uid, c.uid);
      expect(leido.token, c.token);
      expect(c.texto, 'rutix:v1:abc123XYZ:Kq7mT2pLx9WvRb4N');
    });

    test('textos que no son de Rutix se rechazan', () {
      for (final t in [
        null,
        '',
        'https://google.com',
        'rutix:v1:abc',
        'otraapp:v1:abc:Kq7mT2pLx9WvRb4N',
        'rutix:v1:abc:corto',
        'rutix:v1:ab-c:Kq7mT2pLx9WvRb4N',
      ]) {
        expect(CodigoQr.leer(t), isNull, reason: '«$t» debería ser inválido');
      }
    });

    test('cada trabajador recibe un token distinto', () {
      final r = Random(42);
      final tokens = List.generate(1000, (_) => CodigoQr.nuevoToken(r)).toSet();
      expect(tokens.length, 1000);
      expect(tokens.first.length, 16);
    });
  });

  group('Validación del abordaje (criterio de aceptación RF-05)', () {
    const qr = CodigoQr('uidTrabajador', 'Kq7mT2pLx9WvRb4N');

    test('un QR válido se registra', () {
      expect(
        validarAbordaje(codigo: qr, tokenAsignado: qr.token, yaAbordo: false),
        ResultadoAbordaje.registrado,
      );
    });

    test('el mismo QR otra vez se rechaza', () {
      expect(
        validarAbordaje(codigo: qr, tokenAsignado: qr.token, yaAbordo: true),
        ResultadoAbordaje.duplicado,
      );
    });

    test('un QR ilegible se rechaza', () {
      expect(
        validarAbordaje(
            codigo: CodigoQr.leer('hola'), tokenAsignado: 'x', yaAbordo: false),
        ResultadoAbordaje.invalido,
      );
    });

    test('un QR con token falso o antiguo se rechaza', () {
      expect(
        validarAbordaje(
            codigo: qr, tokenAsignado: 'OtroTokenDistinto1', yaAbordo: false),
        ResultadoAbordaje.invalido,
      );
    });

    test('un trabajador de otra ruta se rechaza', () {
      expect(
        validarAbordaje(codigo: qr, tokenAsignado: null, yaAbordo: false),
        ResultadoAbordaje.otraRuta,
      );
    });

    test('un abordaje por trabajador y día', () {
      expect(claveFecha(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
      expect(idAbordaje('2026-03-07', 'uid1'), '2026-03-07_uid1');
      expect(idAbordaje('2026-03-08', 'uid1'),
          isNot(idAbordaje('2026-03-07', 'uid1')));
    });
  });

  group('Códigos QR faltantes (migración automática)', () {
    Usuario u(String uid, Rol rol, {String? ruta, String? qr}) => Usuario(
        uid: uid,
        nombre: uid,
        correo: '$uid@rutix.com',
        rol: rol,
        rutaId: ruta,
        codigoQr: qr);

    test('solo se reparan trabajadores con ruta y sin código', () {
      final usuarios = [
        u('viejo', Rol.trabajador, ruta: 'R03'), // asignado antes del QR
        u('nuevo', Rol.trabajador, ruta: 'R03', qr: 'Kq7mT2pLx9WvRb4N'),
        u('sinRuta', Rol.trabajador),
        u('conductor', Rol.conductor, ruta: 'R03'),
        u('admin', Rol.admin),
      ];
      expect(Repositorio.sinCodigoQr(usuarios).map((x) => x.uid), ['viejo']);
    });
  });

  group('Resumen del administrador (criterio de aceptación RF-06)', () {
    test('3 abordajes de 5 asignados muestra "3 de 5"', () {
      final asignados = ['a', 'b', 'c', 'd', 'e'];
      final abordaron = ['a', 'c', 'e'];
      final n = contarAbordaron(asignados, abordaron);
      expect(resumenAbordaje(n, asignados.length), '3 de 5');
    });

    test('no cuenta a quien ya no está asignado a la ruta', () {
      expect(contarAbordaron(['a', 'b'], ['a', 'z']), 1);
    });

    testWidgets('la tarjeta muestra "Abordaron 3 de 5"', (tester) async {
      final ruta = Ruta(
        id: 'R03',
        nombre: 'Ruta 03',
        turno: 'Mañana',
        placa: 'ABC-123',
        paradas: const [
          Parada('A', LatLng(7, -73), '6:00'),
          Parada('B', LatLng(7.1, -73.1), '6:15'),
        ],
      );
      final pasajeros = [
        for (final u in ['a', 'b', 'c', 'd', 'e'])
          Pasajero(uid: u, nombre: 'Trabajador $u', token: 'tok'),
      ];
      final abordajes = [
        for (final u in ['a', 'c', 'e'])
          Abordaje(
              rutaId: 'R03',
              uid: u,
              nombre: 'Trabajador $u',
              fecha: '2026-11-22',
              conductorNombre: 'C'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TarjetaAbordaje(
              ruta: ruta, pasajeros: pasajeros, abordajes: abordajes),
        ),
      ));
      expect(find.text('Abordaron 3 de 5'), findsOneWidget);
    });
  });
}
