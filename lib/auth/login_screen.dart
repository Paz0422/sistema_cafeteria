import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../register_screen.dart';
import 'package:cafeteria_sistema/constants.dart';

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
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cafetería Fusión',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _usuarioController,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
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
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _iniciarSesion,
                    child: _cargando
                        ? const CircularProgressIndicator()
                        : const Text('Ingresar'),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('¿No tienes cuenta? Crear una'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
