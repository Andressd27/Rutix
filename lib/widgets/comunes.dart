import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/rol.dart';
import '../core/senal.dart';
import '../models/ruta.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/conectividad_service.dart';
import '../services/tema_service.dart';
import 'emergencia.dart';

/// Igual que [StreamBuilder], pero crea la consulta una sola vez por [clave].
/// Evita volver a suscribirse a Firestore en cada reconstrucción del widget.
class StreamCacheado<T> extends StatefulWidget {
  const StreamCacheado({
    super.key,
    required this.clave,
    required this.crear,
    required this.builder,
  });

  final Object? clave;
  final Stream<T> Function() crear;
  final AsyncWidgetBuilder<T> builder;

  @override
  State<StreamCacheado<T>> createState() => _StreamCacheadoState<T>();
}

class _StreamCacheadoState<T> extends State<StreamCacheado<T>> {
  late Stream<T> _stream = widget.crear();

  @override
  void didUpdateWidget(StreamCacheado<T> old) {
    super.didUpdateWidget(old);
    if (old.clave != widget.clave) _stream = widget.crear();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<T>(stream: _stream, builder: widget.builder);
}

/// Indicador de qué tan reciente es la posición del vehículo. Se actualiza
/// solo cada 5 s para que el contador avance aunque no lleguen datos nuevos.
class IndicadorSenal extends StatefulWidget {
  const IndicadorSenal({super.key, required this.ultima});
  final DateTime? ultima;

  @override
  State<IndicadorSenal> createState() => _IndicadorSenalState();
}

class _IndicadorSenalState extends State<IndicadorSenal> {
  late final Timer _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(
        const Duration(seconds: 5), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _reloj.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ultima = widget.ultima;
    if (ultima == null) return const SizedBox.shrink();
    final e = estadoSenal(DateTime.now().difference(ultima));
    final (Color fondo, Color texto, IconData icono) = switch (e.nivel) {
      NivelSenal.buena => (
          const Color(0xFFDDF3E8),
          const Color(0xFF00573D),
          Icons.wifi_tethering
        ),
      NivelSenal.demorada => (
          const Color(0xFFFFF3C4),
          const Color(0xFF5C4400),
          Icons.wifi_tethering_error
        ),
      NivelSenal.perdida => (
          const Color(0xFFFCE8E6),
          const Color(0xFF8C1D18),
          Icons.wifi_tethering_off
        ),
    };
    return Container(
      key: Key('senal_${e.nivel.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: texto),
          const SizedBox(width: 6),
          Flexible(
            child: Text(e.texto,
                style: TextStyle(color: texto, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// Barra superior pintada con el color del rol y con su distintivo, para que
/// siempre se sepa si se está usando la app como trabajador, conductor o admin.
class BarraRol extends StatelessWidget implements PreferredSizeWidget {
  const BarraRol(
      {super.key,
      required this.usuario,
      required this.titulo,
      this.rutaNombre = 'Sin ruta'});
  final Usuario usuario;
  final String titulo;

  /// Ruta del usuario, para la alerta de emergencia.
  final String rutaNombre;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(titulo),
      actions: [
        // El administrador atiende las alertas; los demás pueden enviarlas.
        if (!usuario.esAdmin)
          BotonEmergencia(usuario: usuario, rutaNombre: rutaNombre),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: InsigniaRol(rol: usuario.rol, invertida: true),
        ),
      ],
    );
  }
}

/// Etiqueta con ícono y nombre del rol.
class InsigniaRol extends StatelessWidget {
  const InsigniaRol({super.key, required this.rol, this.invertida = false});
  final Rol rol;

  /// `true` = fondo blanco y texto del color del rol (para la barra superior).
  final bool invertida;

  @override
  Widget build(BuildContext context) {
    final fondo = invertida ? Colors.white : rol.color;
    final texto = invertida ? rol.color : Colors.white;
    return Semantics(
      label: 'Rol: ${rol.etiqueta}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(rol.icono, size: 18, color: texto),
            const SizedBox(width: 6),
            Text(rol.etiqueta.toUpperCase(),
                style: TextStyle(
                    color: texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de bienvenida con el rol bien visible.
class TarjetaRol extends StatelessWidget {
  const TarjetaRol({super.key, required this.usuario});
  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final rol = usuario.rol;
    return Card(
      color: rol.color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(rol.icono, color: rol.color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, ${usuario.nombre}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Sesión de ${rol.etiqueta.toLowerCase()}',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                  Text(rol.descripcion,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso fijo cuando no hay internet (RNF-02). Desaparece solo al reconectar.
class BannerConexion extends StatelessWidget {
  const BannerConexion({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConectividadService.instancia.enLinea,
      builder: (context, enLinea, _) {
        if (enLinea) return const SizedBox.shrink();
        return Material(
          color: const Color(0xFFB3261E),
          child: SafeArea(
            bottom: false,
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: const [
                  Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sin conexión. El seguimiento se reanudará solo al volver internet.',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Mensaje centrado para estados vacíos (sin ruta, cargando, error…).
class MensajeVacio extends StatelessWidget {
  const MensajeVacio(
      {super.key, required this.icono, required this.titulo, this.detalle});
  final IconData icono;
  final String titulo;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(titulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (detalle != null) ...[
              const SizedBox(height: 8),
              Text(detalle!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lista de paradas de una ruta, resaltando la parada de recogida.
class ListaParadas extends StatelessWidget {
  const ListaParadas({super.key, required this.ruta, this.paradaResaltada});
  final Ruta ruta;
  final int? paradaResaltada;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        for (var i = 0; i < ruta.paradas.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: i == paradaResaltada ? color : null,
              foregroundColor: i == paradaResaltada
                  ? Theme.of(context).colorScheme.onPrimary
                  : null,
              child: Text('${i + 1}'),
            ),
            title: Text(ruta.paradas[i].nombre),
            subtitle: i == paradaResaltada
                ? const Text('Tu parada de recogida')
                : null,
            trailing: Text(ruta.paradas[i].hora),
          ),
      ],
    );
  }
}

/// Pantalla de perfil común a los tres roles.
class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key, required this.usuario, this.ruta});
  final Usuario usuario;
  final Ruta? ruta;

  @override
  Widget build(BuildContext context) {
    final r = ruta;
    final parada = (r != null &&
            usuario.esTrabajador &&
            usuario.paradaIdx != null &&
            usuario.paradaIdx! < r.paradas.length)
        ? r.paradas[usuario.paradaIdx!].nombre
        : null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TarjetaRol(usuario: usuario),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Nombre'),
                subtitle: Text(usuario.nombre),
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Correo'),
                subtitle: Text(usuario.correo),
              ),
              ListTile(
                leading: Icon(usuario.rol.icono),
                title: const Text('Rol'),
                subtitle: Text(usuario.rol.etiqueta),
              ),
              if (!usuario.esAdmin)
                ListTile(
                  leading: const Icon(Icons.alt_route),
                  title: const Text('Ruta asignada'),
                  subtitle: Text(r == null
                      ? 'Sin asignar'
                      : '${r.nombre} · ${r.turno} · ${r.placa}'),
                ),
              if (parada != null)
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Parada de recogida'),
                  subtitle: Text(parada),
                ),
            ],
          ),
        ),
        const SelectorTema(),
        Card(
          child: ListTile(
            leading: const Icon(Icons.phone_in_talk_outlined),
            title: const Text('Contacto de emergencia'),
            subtitle: const Text('Línea nacional de emergencias: 123'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: AuthService.salir,
          ),
        ),
      ],
    );
  }
}

/// Modo de pantalla: sigue al teléfono, siempre claro o siempre oscuro.
class SelectorTema extends StatelessWidget {
  const SelectorTema({super.key});

  @override
  Widget build(BuildContext context) {
    final servicio = TemaService.instancia;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.contrast),
                SizedBox(width: 16),
                Text('Modo de pantalla', style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: servicio.modo,
              builder: (context, modo, _) => SegmentedButton<ThemeMode>(
                key: const Key('selector_tema'),
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto),
                      label: Text('Sistema')),
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Claro')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Oscuro')),
                ],
                selected: {modo},
                onSelectionChanged: (s) => servicio.cambiar(s.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
