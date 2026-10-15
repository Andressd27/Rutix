import 'package:flutter/material.dart';
import 'login_page.dart';
import 'models.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  void _dialogo(BuildContext context, String titulo, String texto) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = Sesion.actual!;
    final ruta = rutasDemo.firstWhere((r) => r.id == u.rutaId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        const Center(child: CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40))),
        const SizedBox(height: 8),
        Center(
          child: Text(u.nombre, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Información empleado'),
            onTap: () => _dialogo(
              context,
              'Información empleado',
              'Nombre: ${u.nombre}\nCorreo: ${u.correo}\nRol: ${u.rol}\n'
                  'Ruta: ${ruta.nombre} (${ruta.turno})\n'
                  'Punto de recogida: ${u.rol == 'trabajador' ? ruta.paradas[u.paradaIdx].nombre : 'No aplica'}',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.phone_in_talk_outlined),
            title: const Text('Contacto de emergencia'),
            onTap: () => _dialogo(
              context,
              'Contacto de emergencia',
              'Línea de la empresa: 300 000 0000\nLínea nacional de emergencias: 123',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Soporte técnico'),
            onTap: () => _dialogo(
              context,
              'Soporte técnico',
              'Escríbenos a soporte@rutix.com',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              Sesion.actual = null;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ),
      ],
    );
  }
}
