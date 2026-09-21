import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombreController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();
  final _codigoController = TextEditingController();

  String? _error;
  bool _cargando = false;
  bool _passwordVisible = false;
  bool _confirmarVisible = false;

  Future<void> _crearCuenta() async {
    setState(() => _error = null);

    final usuario = _usuarioController.text.trim().toLowerCase();
    final nombre = _nombreController.text.trim();
    final codigo = _codigoController.text.trim();

    if (nombre.isEmpty || usuario.isEmpty || codigo.isEmpty) {
      setState(() => _error = 'Completa nombre, usuario y código');
      return;
    }
    if (_passwordController.text != _confirmarController.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() => _cargando = true);

    final correoInterno = '$usuario$dominioInterno';

    try {
      final credencial = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: correoInterno,
            password: _passwordController.text,
          );

      // El código se valida en las reglas de Firestore (no aquí), y el rol
      // siempre nace 'vendedor': solo un admin puede dar o cambiar roles.
      try {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(credencial.user!.uid)
            .set({
              'nombre': nombre,
              'usuario': usuario,
              'rol': 'vendedor',
              'codigoInvitacion': codigo,
            });
      } on FirebaseException {
        // Si el perfil no se pudo crear (típicamente código incorrecto), se
        // borra la cuenta recién hecha para no dejar un usuario huérfano.
        await credencial.user!.delete();
        if (mounted) {
          setState(() => _error = 'Código de invitación incorrecto');
        }
        return;
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                const Text(
                  '¡Cuenta creada con éxito!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.code == 'email-already-in-use'
            ? 'Ese nombre de usuario ya está en uso'
            : 'No se pudo crear la cuenta';
      });
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Crear cuenta',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre y apellido',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
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
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmarController,
                  obscureText: !_confirmarVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _confirmarVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _confirmarVisible = !_confirmarVisible);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codigoController,
                  decoration: const InputDecoration(
                    labelText: 'Código de invitación',
                    border: OutlineInputBorder(),
                  ),
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
                    onPressed: _cargando ? null : _crearCuenta,
                    child: _cargando
                        ? const CircularProgressIndicator()
                        : const Text('Crear cuenta'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Ya tengo cuenta, volver a iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
