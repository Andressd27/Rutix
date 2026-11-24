/// Qué tan reciente es la última posición recibida del vehículo.
///
/// El conductor envía su posición al moverse y, aunque esté detenido, cada
/// 15 s. Si pasa más tiempo, el trabajador debe saber que el dato es viejo
/// (RNF-02: no confiar en un mapa "congelado").
enum NivelSenal { buena, demorada, perdida }

class EstadoSenal {
  const EstadoSenal(this.nivel, this.texto);
  final NivelSenal nivel;
  final String texto;
}

/// Hasta 45 s (tres envíos perdidos) se considera señal buena.
const limiteSenalBuena = Duration(seconds: 45);

/// Después de 2 minutos se considera que no hay señal.
const limiteSenalPerdida = Duration(minutes: 2);

EstadoSenal estadoSenal(Duration desdeUltima) {
  // Pequeñas diferencias de reloj entre teléfonos pueden dar valores negativos.
  final d = desdeUltima.isNegative ? Duration.zero : desdeUltima;
  final texto = d.inSeconds < 60
      ? 'Última señal hace ${d.inSeconds} s'
      : 'Última señal hace ${d.inMinutes} min';
  if (d <= limiteSenalBuena) return EstadoSenal(NivelSenal.buena, texto);
  if (d <= limiteSenalPerdida) return EstadoSenal(NivelSenal.demorada, texto);
  return EstadoSenal(NivelSenal.perdida,
      'Sin señal del vehículo hace ${d.inMinutes} min · la posición puede no estar al día');
}
