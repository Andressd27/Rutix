/// Vehículo de la empresa: `vehiculos/{placa}`.
class Vehiculo {
  const Vehiculo({
    required this.placa,
    required this.capacidad,
    this.descripcion = '',
  });

  final String placa;
  final int capacidad;
  final String descripcion;

  factory Vehiculo.desdeMapa(String placa, Map<String, dynamic> d) => Vehiculo(
        placa: placa,
        capacidad: (d['capacidad'] as num?)?.toInt() ?? 0,
        descripcion: (d['descripcion'] as String?) ?? '',
      );

  Map<String, dynamic> aMapa() => {
        'capacidad': capacidad,
        'descripcion': descripcion,
      };

  String get etiqueta => descripcion.isEmpty
      ? '$placa · $capacidad puestos'
      : '$placa · $descripcion · $capacidad puestos';
}
