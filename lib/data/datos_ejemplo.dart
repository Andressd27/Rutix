import 'package:latlong2/latlong.dart';

import '../models/ruta.dart';

/// Rutas de ejemplo (área metropolitana de Bucaramanga). El administrador puede
/// cargarlas en Firestore con el botón «Cargar rutas de ejemplo».
final rutasEjemplo = <Ruta>[
  Ruta(
    id: 'R03',
    nombre: 'Ruta 03',
    turno: 'Mañana',
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
    placa: 'GHI-789',
    paradas: [
      Parada('Oficina central', LatLng(7.1193, -73.1227), '10:00 p. m.'),
      Parada('Parada Centro', LatLng(7.1050, -73.1300), '10:15 p. m.'),
      Parada('Parada Floridablanca', LatLng(7.0622, -73.0864), '10:35 p. m.'),
      Parada('Piedecuesta - Parque', LatLng(6.9886, -73.0505), '10:55 p. m.'),
    ],
  ),
];
