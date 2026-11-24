/// Reglas puras para crear y editar rutas, paradas y vehículos (RF-07).
/// No dependen de Flutter ni de Firebase, así que se prueban directamente.
library;

const turnos = ['Mañana', 'Tarde', 'Noche'];

/// Datos mínimos de una parada para validarla.
class ParadaBorrador {
  const ParadaBorrador({required this.nombre, required this.hora});
  final String nombre;
  final String hora;
}

/// Errores de una ruta antes de guardarla. Lista vacía = se puede guardar.
List<String> validarRuta({
  required String nombre,
  required String turno,
  required List<ParadaBorrador> paradas,
}) {
  final errores = <String>[];
  if (nombre.trim().length < 3) {
    errores.add('El nombre de la ruta debe tener al menos 3 caracteres.');
  }
  if (!turnos.contains(turno)) errores.add('Elige el turno de la ruta.');
  if (paradas.length < 2) {
    errores.add('La ruta necesita al menos 2 paradas (toca el mapa para agregarlas).');
  }
  for (var i = 0; i < paradas.length; i++) {
    if (paradas[i].nombre.trim().isEmpty) {
      errores.add('La parada ${i + 1} no tiene nombre.');
    }
    if (paradas[i].hora.trim().isEmpty) {
      errores.add('La parada ${i + 1} no tiene hora.');
    }
  }
  return errores;
}

/// Hora en el formato que usa la app: `5:30 a. m.`, `10:05 p. m.`
String formatoHora(int hora24, int minuto) {
  final sufijo = hora24 < 12 ? 'a. m.' : 'p. m.';
  final h12 = hora24 % 12 == 0 ? 12 : hora24 % 12;
  return '$h12:${minuto.toString().padLeft(2, '0')} $sufijo';
}

/// Lee una hora escrita como `5:30 a. m.` (también acepta `am`/`pm` y 24 h).
/// Devuelve `(hora24, minuto)` o `null` si no se entiende.
(int, int)? leerHora(String texto) {
  final t = texto.toLowerCase().replaceAll('.', '').replaceAll(' ', '');
  final m = RegExp(r'^(\d{1,2}):(\d{2})(am|pm)?$').firstMatch(t);
  if (m == null) return null;
  var h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  final ampm = m.group(3);
  if (min > 59) return null;
  if (ampm == null) {
    if (h > 23) return null;
  } else {
    if (h < 1 || h > 12) return null;
    if (ampm == 'am' && h == 12) h = 0;
    if (ampm == 'pm' && h != 12) h += 12;
  }
  return (h, min);
}

/// Placa en mayúsculas y con guion: `abc123` → `ABC-123`.
String normalizarPlaca(String texto) {
  final limpio = texto.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (limpio.length == 6) {
    return '${limpio.substring(0, 3)}-${limpio.substring(3)}';
  }
  return limpio;
}

/// Placa colombiana de vehículo: 3 letras y 3 números (`ABC-123`).
bool placaValida(String texto) =>
    RegExp(r'^[A-Z]{3}-\d{3}$').hasMatch(normalizarPlaca(texto));

/// Errores de un vehículo antes de guardarlo.
List<String> validarVehiculo({required String placa, required int? capacidad}) {
  final errores = <String>[];
  if (!placaValida(placa)) {
    errores.add('La placa debe tener 3 letras y 3 números, por ejemplo ABC-123.');
  }
  if (capacidad == null || capacidad < 1 || capacidad > 80) {
    errores.add('La capacidad debe estar entre 1 y 80 pasajeros.');
  }
  return errores;
}

/// Al editar una ruta, las paradas se pueden reordenar o borrar. Los
/// trabajadores guardan su parada por **posición**, así que hay que traducirla.
///
/// [origen] tiene una entrada por cada parada nueva: la posición que tenía
/// antes, o `null` si es una parada agregada. Devuelve la nueva posición de la
/// parada que estaba en [anterior], o `null` si esa parada se eliminó.
int? nuevaPosicion(List<int?> origen, int? anterior) {
  if (anterior == null) return null;
  final i = origen.indexOf(anterior);
  return i < 0 ? null : i;
}

/// `true` si cambió la ubicación u orden de las paradas (hay que recalcular
/// el camino por calles). Cambiar solo nombres u horas no obliga a recalcular.
bool cambioElRecorrido(
    List<(double, double)> antes, List<(double, double)> despues) {
  if (antes.length != despues.length) return true;
  for (var i = 0; i < antes.length; i++) {
    if (antes[i] != despues[i]) return true;
  }
  return false;
}
