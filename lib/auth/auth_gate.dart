import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'package:cafeteria_sistema/users/home_vendedor.dart';
import 'package:cafeteria_sistema/admin/home_admin.dart';

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

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Scaffold(
                body: Center(
                  child: Text('No se encontró tu perfil de usuario'),
                ),
              );
            }

            final datos = userSnapshot.data!.data() as Map<String, dynamic>;
            final rol = datos['rol'] as String;
            final nombre = datos['nombre'] as String;

            if (rol == 'vendedor' || rol == 'invitado') {
              return HomeVendedor(nombre: nombre);
            }

            return HomeAdmin(nombre: nombre);
          },
        );
      },
    );
  }
}
