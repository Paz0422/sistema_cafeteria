import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/auth_gate.dart';
import 'theme/marca.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBlfcx23_IAk381nkkE1ESndRaPbxKk2z0",
      authDomain: "cafeteria-sistema-123ef.firebaseapp.com",
      projectId: "cafeteria-sistema-123ef",
      storageBucket: "cafeteria-sistema-123ef.firebasestorage.app",
      messagingSenderId: "299057933846",
      appId: "1:299057933846:web:7de060d35426597e63cf37",
      measurementId: "G-YZQN3BR6T3",
    ),
  );

  // En web la caché local viene desactivada por defecto. Con ella activa, las
  // lecturas se sirven desde el navegador sin internet y las escrituras
  // quedan en cola hasta que vuelva la conexión. Multi-pestaña evita que una
  // segunda pestaña abierta se quede sin caché.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    webPersistentTabManager: WebPersistentMultipleTabManager(),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  /// Pantalla inicial. Solo se cambia en las pruebas: AuthGate necesita
  /// Firebase inicializado.
  final Widget home;

  const MyApp({super.key, this.home = const AuthGate()});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cafetería Fusión',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: temaFusion(),
      home: home,
    );
  }
}
