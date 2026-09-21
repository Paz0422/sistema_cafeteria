import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth/auth_gate.dart';

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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cafetería Fusión',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.brown, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}
