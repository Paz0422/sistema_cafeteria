import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'package:cafeteria_sistema/users/home_vendedor.dart';
import 'package:cafeteria_sistema/admin/home_admin.dart';
import '../widgets/logo_fusion.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        final uid = authSnapshot.data!.uid;

        // Se escucha el perfil en vivo: así una cuenta recién registrada
        // no falla por llegar antes que su perfil, y una cuenta pendiente
        // entra sola apenas un admin la aprueba.
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError) {
              return const _PantallaEspera(
                mensaje: 'No se pudo cargar tu perfil de usuario.',
              );
            }
            if (!userSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final doc = userSnapshot.data!;
            if (!doc.exists) {
              return const _PantallaEspera(
                mensaje: 'No se encontró tu perfil de usuario.',
              );
            }

            final datos = doc.data()!;
            final nombre = datos['nombre'] as String? ?? '';

            return switch (datos['rol']) {
              'admin' => HomeAdmin(nombre: nombre),
              'vendedor' => HomeVendedor(nombre: nombre),
              _ => const _PantallaEspera(
                mensaje:
                    'Tu cuenta no tiene acceso al sistema. Pídele a un '
                    'administrador que la active y esta pantalla se '
                    'actualizará sola.',
              ),
            };
          },
        );
      },
    );
  }
}

class _PantallaEspera extends StatelessWidget {
  final String mensaje;

  const _PantallaEspera({required this.mensaje});

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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MascotaFusion(tamano: 140),
                const SizedBox(height: 16),
                Text(mensaje, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
