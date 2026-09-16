import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'clientes_screen.dart';
import 'productos_screen.dart';

class HomeAdmin extends StatelessWidget {
  final String nombre;

  const HomeAdmin({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cafetería Fusión — Admin: $nombre'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(24),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _TarjetaMenu(
            icono: Icons.inventory_2,
            titulo: 'Productos y precios',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProductosScreen(esAdmin: true),
                ),
              );
            },
          ),
          _TarjetaMenu(
            icono: Icons.assignment_ind,
            titulo: 'Clientes y crédito',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ClientesScreen()),
              );
            },
          ),
          _TarjetaMenu(icono: Icons.store, titulo: 'Sucursales', onTap: () {}),
          _TarjetaMenu(
            icono: Icons.bar_chart,
            titulo: 'Reportes',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _TarjetaMenu extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  const _TarjetaMenu({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 48),
            const SizedBox(height: 12),
            Text(titulo, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
