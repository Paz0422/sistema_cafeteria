import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../register_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/acceso.dart';
import '../widgets/pantalla_marca.dart';
import '../theme/marca.dart';

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

    final usuario = normalizarUsuario(_usuarioController.text);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correoDeAcceso(
          usuario,
          generacion: await _generacionDe(usuario),
        ),
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

  /// Si un admin restableció el acceso de este usuario, su cuenta actual es
  /// una generación posterior a la primera. Si no se puede consultar (sin
  /// internet, usuario inexistente), se prueba con la primera.
  Future<int> _generacionDe(String usuario) async {
    if (usuario.isEmpty) return 1;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('accesos')
          .doc(idAcceso(usuario))
          .get();
      return (doc.data()?['gen'] as num?)?.toInt() ?? 1;
    } on FirebaseException {
      return 1;
    }
  }

  void _olvideContrasena() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Olvidaste tu contraseña?'),
        content: const Text(
          'Pídele a un administrador que te restablezca la contraseña desde '
          'la sección Usuarios. Te dará una contraseña temporal: entra con '
          'ella y el sistema te pedirá elegir una nueva.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _cargando ? null : _olvideContrasena,
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: const TextStyle(color: Marca.peligro),
              ),
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
