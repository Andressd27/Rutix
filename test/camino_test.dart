import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutix/core/geo.dart';
import 'package:rutix/core/polilinea.dart';
import 'package:rutix/data/datos_ejemplo.dart';
import 'package:rutix/models/ruta.dart';
import 'package:rutix/services/osrm_service.dart';

void main() {
  group('Polilínea codificada', () {
    test('decodifica el ejemplo oficial de Google (precisión 5)', () {
      final p = Polilinea.decodificar('_p~iF~ps|U_ulLnnqC_mqNvxq`@', precision: 5);
      expect(p, const [
        LatLng(38.5, -120.2),
        LatLng(40.7, -120.95),
        LatLng(43.252, -126.453),
      ]);
    });

    test('no usa operadores de bits (en la web fallan con números negativos)',
        () {
      // En JavaScript `~`, `<<`, `>>` y `|` trabajan con enteros de 32 bits
      // sin signo; con ellos las longitudes de Colombia (-73°) se rompían en
      // el navegador aunque estas pruebas (que corren en la VM) pasaran.
      final codigo = File('lib/core/polilinea.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(codigo, isNot(matches(RegExp(r'<<|>>|~\(|[^|]\|[^|]|&'))));
    });

    test('codificar y decodificar devuelve los mismos puntos (precisión 6)', () {
      const puntos = [LatLng(7.071512, -73.169801), LatLng(7.119300, -73.122700)];
      expect(Polilinea.decodificar(Polilinea.codificar(puntos)), puntos);
    });
  });

  group('Respuesta real de OSRM para la Ruta 03', () {
    final cuerpo = File('test/datos/osrm_r03.json').readAsStringSync();
    final t = OsrmService.interpretar(cuerpo);
    final camino = t.puntos;
    final r03 = rutasEjemplo.firstWhere((r) => r.id == 'R03');

    test('trae distancia, duración y un camino con muchos puntos', () {
      expect(t.distanciaMetros, closeTo(19515, 1));
      expect(t.duracionSegundos, closeTo(2008.8, 1));
      expect(camino.length, greaterThan(100),
          reason: 'por calles hay muchos más puntos que las 4 paradas');
    });

    test('empieza y termina en la primera y última parada (±100 m)', () {
      expect(Geo.metros(camino.first, r03.paradas.first.punto), lessThan(100));
      expect(Geo.metros(camino.last, r03.paradas.last.punto), lessThan(100));
    });

    test('la longitud del camino coincide con la distancia de OSRM (±2 %)', () {
      final largo = Geo.longitud(camino, 0, camino.length - 1);
      expect(largo, closeTo(t.distanciaMetros, t.distanciaMetros * 0.02));
    });

    test('el camino por calles es más largo que la línea recta', () {
      final recta = Geo.longitud(r03.trazado, 0, r03.trazado.length - 1);
      expect(t.distanciaMetros, greaterThan(recta));
    });

    test('una ruta guardada con camino lo usa para dibujar y medir', () {
      final ruta = Ruta(
        id: 'R03',
        nombre: 'Ruta 03',
        turno: 'Mañana',
        placa: 'ABC-123',
        paradas: r03.paradas,
        caminoPolilinea: t.polilinea,
        distanciaMetros: t.distanciaMetros,
        duracionSegundos: t.duracionSegundos,
      );
      expect(ruta.tieneCamino, isTrue);
      expect(ruta.camino.length, camino.length);
      expect(ruta.velocidadMedia, closeTo(19515 / 2008.8, 0.01));
    });

    test('una ruta sin camino usa líneas rectas entre paradas', () {
      expect(r03.tieneCamino, isFalse);
      expect(r03.camino, r03.trazado);
      expect(r03.velocidadMedia, Geo.velocidadPorDefecto);
    });

    group('Avance del vehículo hacia la parada 3 (RF-03)', () {
      final paradas = r03.trazado;
      const parada = 2; // Parada Centro
      final simulacion = Geo.remuestrear(camino, 100);
      final iParada = Geo.indiceMasCercano(simulacion, paradas[parada]);

      test('la distancia por la vía disminuye mientras se acerca', () {
        // La Ruta 03 va hasta la Parada Sur y regresa por la misma vía:
        // siguiendo al vehículo hacia adelante no se confunde ida con vuelta.
        Avance? anterior;
        for (var i = 0; i < iParada; i += 5) {
          final a = Geo.avance(
              camino: camino, paradas: paradas, paradaIdx: parada,
              vehiculo: simulacion[i], pista: anterior?.indice);
          expect(a.yaPaso, isFalse, reason: 'punto $i');
          if (anterior != null) {
            expect(a.metros!, lessThan(anterior.metros!), reason: 'punto $i');
          }
          anterior = a;
        }
      });

      test('sin seguimiento previo, la ida y la vuelta se pueden confundir', () {
        // Documenta por qué se necesita la pista: en el tramo de regreso el
        // punto más cercano de todo el camino puede estar en el tramo de ida.
        final enLaVuelta = simulacion[150];
        final sinPista = Geo.ubicarEnCamino(camino, enLaVuelta);
        var conPista = 0;
        for (var i = 0; i <= 150; i += 5) {
          conPista = Geo.ubicarEnCamino(camino, simulacion[i], pista: conPista);
        }
        expect(conPista, greaterThan(sinPista));
      });

      test('mide por la carretera, no en línea recta', () {
        final inicio = simulacion.first;
        final a = Geo.avance(
            camino: camino, paradas: paradas, paradaIdx: parada,
            vehiculo: inicio);
        expect(a.metros!, greaterThan(Geo.metros(inicio, paradas[parada])));
      });

      test('detecta cuando el vehículo ya pasó por la parada', () {
        final despues = simulacion[(iParada + 8).clamp(0, simulacion.length - 1)];
        final a = Geo.avance(
            camino: camino, paradas: paradas, paradaIdx: parada,
            vehiculo: despues);
        expect(a.yaPaso, isTrue);
        expect(a.metros, isNull);
      });

      test('al llegar a la parada no la da por pasada', () {
        final a = Geo.avance(
            camino: camino, paradas: paradas, paradaIdx: parada,
            vehiculo: paradas[parada]);
        expect(a.yaPaso, isFalse);
        expect(a.metros!, lessThan(Geo.toleranciaParadaMetros + 50));
      });
    });
  });

  group('Remuestreo para la simulación', () {
    test('los puntos quedan a la distancia pedida', () {
      const recta = [LatLng(7.0, -73.0), LatLng(7.02, -73.0)]; // ≈ 2.2 km
      final puntos = Geo.remuestrear(recta, 100);
      for (var i = 1; i < puntos.length - 1; i++) {
        expect(Geo.metros(puntos[i - 1], puntos[i]), closeTo(100, 1));
      }
      expect(puntos.first, recta.first);
      expect(puntos.last, recta.last);
    });

    test('el tiempo estimado usa la velocidad media de la ruta', () {
      // 3 km a 10 m/s = 5 minutos
      expect(Geo.minutosEstimados(3000, velocidad: 10), 5);
    });
  });
}
