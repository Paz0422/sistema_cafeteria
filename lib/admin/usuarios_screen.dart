import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/marca.dart';
import '../utils/acceso.dart';
import '../utils/restablecer_acceso.dart';

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
                      ? const TextStyle(color: Marca.alerta)
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
                          usuario: usuario,
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
  final String usuario;
  final String rolActual;

  const _DialogoUsuario({
    required this.uid,
    required this.nombre,
    required this.usuario,
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

  Future<void> _restablecer() async {
    final temporal = generarContrasenaTemporal();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: Text(
          'Se le pondrá a ${widget.nombre} la contraseña temporal '
          '$temporal. Su contraseña actual dejará de servir y tendrá que '
          'elegir una nueva al entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      await restablecerContrasena(
        uidAnterior: widget.uid,
        usuario: widget.usuario,
        nombre: widget.nombre,
        rol: widget.rolActual,
        contrasenaTemporal: temporal,
      );
      if (!mounted) return;
      final navegador = Navigator.of(context);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _DialogoClaveTemporal(nombre: widget.nombre, clave: temporal),
      );
      navegador.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo restablecer: $e')));
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _guardando ? null : _restablecer,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Restablecer contraseña'),
            ),
          ],
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

/// Muestra la contraseña temporal una sola vez para que el admin se la pase
/// a la persona. No se guarda en ninguna parte.
class _DialogoClaveTemporal extends StatelessWidget {
  final String nombre;
  final String clave;

  const _DialogoClaveTemporal({required this.nombre, required this.clave});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contraseña restablecida'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dale esta contraseña temporal a $nombre. Al entrar tendrá que '
            'elegir una nueva. Esta es la única vez que se muestra.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Marca.carbon,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Marca.dorado.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    clave,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: Marca.dorado,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar',
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: clave));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contraseña copiada')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
