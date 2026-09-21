import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../register_screen.dart';
import 'package:cafeteria_sistema/constants.dart';
import '../widgets/pantalla_marca.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _error;
  bool _cargando = false;
  bool _passwordVisible = false;

  Future<void> _iniciarSesion() async {
    setState(() {
      _error = null;
      _cargando = true;
    });

    final usuario = _usuarioController.text.trim().toLowerCase();
    final correoInterno = '$usuario$dominioInterno';

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correoInterno,
        password: _passwordController.text,
      );
    } on FirebaseAuthException {
      setState(() {
        _error = 'Usuario o contraseña incorrectos';
      });
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PantallaMarca(
      titulo: 'Bienvenido',
      subtitulo: 'Ingresa con tu usuario y contraseña',
      pie: BotonPieMarca(
        texto: '¿No tienes cuenta? Crear una',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
          );
        },
      ),
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _usuarioController,
            decoration: const InputDecoration(
              labelText: 'Usuario',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _passwordVisible = !_passwordVisible);
                },
              ),
            ),
            onSubmitted: (_) => _iniciarSesion(),
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _cargando ? null : _iniciarSesion,
              child: _cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Ingresar'),
            ),
          ),
        ],
      ),
    );
  }
}
