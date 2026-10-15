import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class Parada {
  final String nombre;
  final LatLng punto;
  final String hora;
  const Parada(this.nombre, this.punto, this.hora);
}

class Ruta {
  final String id;
  final String nombre;
  final String turno; // Mañana / Tarde / Noche
  final String conductor;
  final String placa;
  final List<Parada> paradas;
  const Ruta({
    required this.id,
    required this.nombre,
    required this.turno,
    required this.conductor,
    required this.placa,
    required this.paradas,
  });

  List<LatLng> get trazado => paradas.map((p) => p.punto).toList();
}

class UsuarioDemo {
  final String nombre;
  final String correo;
  final String clave;
  final String rol; // 'trabajador' | 'conductor'
  final String rutaId;
  final int paradaIdx; // punto de recogida (solo trabajador)
  const UsuarioDemo({
    required this.nombre,
    required this.correo,
    required this.clave,
    required this.rol,
    required this.rutaId,
    required this.paradaIdx,
  });
}

class Sesion {
  static UsuarioDemo? actual;
}

class Evento {
  final String texto;
  final IconData icono;
  final DateTime hora;
  Evento(this.texto, this.icono) : hora = DateTime.now();

  String get hace {
    final min = DateTime.now().difference(hora).inMinutes;
    return min < 1 ? 'Hace instantes' : 'Hace $min min';
  }
}

// ---------------- Datos de prueba (sin base de datos) ----------------
// Coordenadas aproximadas del área metropolitana de Bucaramanga:
// reemplázalas por las reales de tu ruta.

final usuariosDemo = <UsuarioDemo>[
  const UsuarioDemo(
    nombre: 'Trabajador Demo',
    correo: 'trabajador@rutix.com',
    clave: '1234',
    rol: 'trabajador',
    rutaId: 'R03',
    paradaIdx: 2,
  ),
  const UsuarioDemo(
    nombre: 'Conductor Demo',
    correo: 'conductor@rutix.com',
    clave: '1234',
    rol: 'conductor',
    rutaId: 'R03',
    paradaIdx: 0,
  ),
];

final rutasDemo = <Ruta>[
  Ruta(
    id: 'R03',
    nombre: 'Ruta 03',
    turno: 'Mañana',
    conductor: 'Conductor Demo',
    placa: 'ABC-123',
    paradas: [
      Parada('Girón - Parque Principal', LatLng(7.0715, -73.1698), '5:30 a. m.'),
      Parada('Parada Sur', LatLng(7.0870, -73.1480), '5:45 a. m.'),
      Parada('Parada Centro', LatLng(7.1050, -73.1300), '6:00 a. m.'),
      Parada('Oficina central', LatLng(7.1193, -73.1227), '6:15 a. m.'),
    ],
  ),
  Ruta(
    id: 'R04',
    nombre: 'Ruta 04',
    turno: 'Tarde',
    conductor: 'Conductor 2',
    placa: 'DEF-456',
    paradas: [
      Parada('Floridablanca - Parque', LatLng(7.0622, -73.0864), '1:30 p. m.'),
      Parada('Parada Cañaveral', LatLng(7.0780, -73.1050), '1:45 p. m.'),
      Parada('Parada Norte', LatLng(7.1000, -73.1150), '2:00 p. m.'),
      Parada('Oficina central', LatLng(7.1193, -73.1227), '2:15 p. m.'),
    ],
  ),
  Ruta(
    id: 'R05',
    nombre: 'Ruta 05',
    turno: 'Noche',
    conductor: 'Conductor 3',
    placa: 'GHI-789',
    paradas: [
      Parada('Oficina central', LatLng(7.1193, -73.1227), '10:00 p. m.'),
      Parada('Parada Centro', LatLng(7.1050, -73.1300), '10:15 p. m.'),
      Parada('Parada Floridablanca', LatLng(7.0622, -73.0864), '10:35 p. m.'),
      Parada('Piedecuesta - Parque', LatLng(6.9886, -73.0505), '10:55 p. m.'),
    ],
  ),
];
