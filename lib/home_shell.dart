import 'package:flutter/material.dart';
import 'config_page.dart';
import 'inicio_page.dart';
import 'mapa_page.dart';
import 'mis_rutas_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;

  void _ir(int i) => setState(() => _indice = i);

  @override
  Widget build(BuildContext context) {
    final paginas = <Widget>[
      InicioPage(onVerMapa: () => _ir(2)),
      const MisRutasPage(),
      const MapaPage(),
      const ConfigPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _ir(3),
          ),
        ],
      ),
      body: IndexedStack(index: _indice, children: paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _ir,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.alt_route), label: 'Mis rutas'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
