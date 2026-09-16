import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pos/apertura_caja_screen.dart';

class HomeVendedor extends StatelessWidget {
  final String nombre;

  const HomeVendedor({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cafetería Fusión'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Hola, $nombre',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AperturaCajaScreen(vendedorNombre: nombre),
                    ),
                  );
                },
                icon: const Icon(Icons.point_of_sale),
                label: const Text(
                  'Abrir turno',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
