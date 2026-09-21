import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/marca.dart';
import '../widgets/pantalla_marca.dart';

/// Se muestra cuando un admin restableció la contraseña de la persona: entró
/// con una temporal y tiene que elegir la suya antes de seguir.
class CambiarClaveScreen extends StatefulWidget {
  final String uid;

  /// Se puede reemplazar en pruebas para no depender de Firebase.
  final Future<void> Function(String nueva)? guardar;

  const CambiarClaveScreen({super.key, required this.uid, this.guardar});

  @override
  State<CambiarClaveScreen> createState() => _CambiarClaveScreenState();
}

class _CambiarClaveScreenState extends State<CambiarClaveScreen> {
  final _nuevaController = TextEditingController();
  final _confirmarController = TextEditingController();

  String? _error;
  bool _cargando = false;
  bool _visible = false;

  @override
  void dispose() {
    _nuevaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _guardarEnFirebase(String nueva) async {
    await FirebaseAuth.instance.currentUser!.updatePassword(nueva);
    // Al bajar la marca, AuthGate deja pasar a la persona a su panel.
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.uid)
        .update({'debeCambiarClave': false});
  }

  Future<void> _cambiar() async {
    final nueva = _nuevaController.text;
    if (nueva.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (nueva != _confirmarController.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _error = null;
      _cargando = true;
    });
    try {
      await (widget.guardar ?? _guardarEnFirebase)(nueva);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e.code) {
            'requires-recent-login' =>
              'Por seguridad, cierra sesión y vuelve a entrar con la '
                  'contraseña temporal.',
            'weak-password' => 'Elige una contraseña más segura',
            _ => 'No se pudo cambiar la contraseña',
          };
        });
      }
    } on FirebaseException {
      if (mounted) {
        setState(() => _error = 'No se pudo cambiar la contraseña');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PantallaMarca(
      titulo: 'Elige tu contraseña',
      subtitulo:
          'Entraste con una contraseña temporal. Elige una nueva para seguir.',
      pie: BotonPieMarca(
        texto: 'Cerrar sesión',
        onPressed: () => FirebaseAuth.instance.signOut(),
      ),
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nuevaController,
            obscureText: !_visible,
            decoration: InputDecoration(
              labelText: 'Contraseña nueva',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_visible ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmarController,
            obscureText: !_visible,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onSubmitted: (_) => _cargando ? null : _cambiar(),
          ),
          const SizedBox(height: 24),
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
              onPressed: _cargando ? null : _cambiar,
              child: _cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Guardar contraseña'),
            ),
          ),
        ],
      ),
    );
  }
}
