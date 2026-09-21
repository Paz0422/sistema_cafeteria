import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsuariosScreen extends StatelessWidget {
  final bool mostrarAppBar;

  const UsuariosScreen({super.key, this.mostrarAppBar = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mostrarAppBar ? AppBar(title: const Text('Usuarios')) : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('No se pudo cargar: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final miUid = FirebaseAuth.instance.currentUser?.uid;
          bool esPendiente(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              !const ['admin', 'vendedor'].contains(d.data()['rol']);

          // Las cuentas sin acceso van primero para que no se pasen por alto.
          final usuarios = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final porEstado = (esPendiente(b) ? 1 : 0).compareTo(
                esPendiente(a) ? 1 : 0,
              );
              if (porEstado != 0) return porEstado;
              return ('${a.data()['nombre']}').compareTo(
                '${b.data()['nombre']}',
              );
            });

          if (usuarios.isEmpty) {
            return const Center(child: Text('Aún no hay usuarios'));
          }

          return ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (context, indice) {
              final doc = usuarios[indice];
              final datos = doc.data();
              final nombre = datos['nombre'] as String? ?? '';
              final usuario = datos['usuario'] as String? ?? '';
              final rol = datos['rol'] as String? ?? 'pendiente';
              final pendiente = esPendiente(doc);
              final esYo = doc.id == miUid;

              return ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    rol == 'admin'
                        ? Icons.admin_panel_settings
                        : pendiente
                        ? Icons.hourglass_top
                        : Icons.person,
                  ),
                ),
                title: Text(esYo ? '$nombre (tú)' : nombre),
                subtitle: Text(
                  '@$usuario · '
                  '${rol == 'admin'
                      ? 'Admin'
                      : pendiente
                      ? 'Sin acceso'
                      : 'Vendedor'}',
                  style: pendiente
                      ? const TextStyle(color: Colors.orange)
                      : null,
                ),
                trailing: esYo ? null : const Icon(Icons.edit_outlined),
                onTap: esYo
                    ? null
                    : () => showDialog(
                        context: context,
                        builder: (context) => _DialogoUsuario(
                          uid: doc.id,
                          nombre: nombre,
                          rolActual: rol,
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DialogoUsuario extends StatefulWidget {
  final String uid;
  final String nombre;
  final String rolActual;

  const _DialogoUsuario({
    required this.uid,
    required this.nombre,
    required this.rolActual,
  });

  @override
  State<_DialogoUsuario> createState() => _DialogoUsuarioState();
}

class _DialogoUsuarioState extends State<_DialogoUsuario> {
  late String _rol = const ['admin', 'vendedor'].contains(widget.rolActual)
      ? widget.rolActual
      : 'pendiente';
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.uid)
          .update({'rol': _rol});

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.nombre),
      content: SizedBox(
        width: 360,
        child: DropdownButtonFormField<String>(
          initialValue: _rol,
          decoration: const InputDecoration(
            labelText: 'Rol',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'pendiente',
              child: Text('Sin acceso (cuenta desactivada)'),
            ),
            DropdownMenuItem(value: 'vendedor', child: Text('Vendedor')),
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
          ],
          onChanged: (valor) => setState(() => _rol = valor ?? 'pendiente'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
