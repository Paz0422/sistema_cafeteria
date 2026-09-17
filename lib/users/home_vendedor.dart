import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pos/selector_sucursal_apertura.dart';

class HomeVendedor extends StatelessWidget {
  final String nombre;

  const HomeVendedor({super.key, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, $nombre'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SelectorSucursalApertura(nombreVendedor: nombre),
    );
  }
}
