import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sucursal.dart';

class SucursalesScreen extends StatelessWidget {
  final bool mostrarAppBar;

  const SucursalesScreen({super.key, this.mostrarAppBar = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mostrarAppBar ? AppBar(title: const Text('Sucursales')) : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _abrirFormulario(context, null, []),
                icon: const Icon(Icons.add_business),
                label: const Text('Agregar sucursal'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('sucursales')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sucursales =
                    snapshot.data!.docs.map(Sucursal.fromDoc).toList()
                      ..sort((a, b) => a.nombre.compareTo(b.nombre));

                if (sucursales.isEmpty) {
                  return const Center(
                    child: Text('Aún no hay sucursales creadas'),
                  );
                }

                return ListView.builder(
                  itemCount: sucursales.length,
                  itemBuilder: (context, indice) {
                    final sucursal = sucursales[indice];
                    final compartidas = sucursales
                        .where(
                          (s) =>
                              s.id != sucursal.id &&
                              s.grupoClientes == sucursal.grupoClientes,
                        )
                        .map((s) => s.nombre)
                        .toList();

                    return ListTile(
                      leading: const Icon(Icons.storefront),
                      title: Text(sucursal.nombre),
                      subtitle: Text(
                        [
                          if (sucursal.direccion.isNotEmpty) sucursal.direccion,
                          compartidas.isEmpty
                              ? 'Clientes propios (no comparte con nadie)'
                              : 'Comparte clientes con: ${compartidas.join(', ')}',
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _abrirFormulario(context, sucursal, sucursales),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _abrirFormulario(
    BuildContext context,
    Sucursal? sucursal,
    List<Sucursal> todasLasSucursales,
  ) {
    showDialog(
      context: context,
      builder: (context) => _DialogoSucursal(
        sucursal: sucursal,
        otrasSucursales: todasLasSucursales
            .where((s) => s.id != sucursal?.id)
            .toList(),
      ),
    );
  }
}

class _DialogoSucursal extends StatefulWidget {
  final Sucursal? sucursal;
  final List<Sucursal> otrasSucursales;

  const _DialogoSucursal({this.sucursal, required this.otrasSucursales});

  @override
  State<_DialogoSucursal> createState() => _DialogoSucursalState();
}

class _DialogoSucursalState extends State<_DialogoSucursal> {
  late final _nombreController = TextEditingController(
    text: widget.sucursal?.nombre,
  );
  late final _direccionController = TextEditingController(
    text: widget.sucursal?.direccion,
  );
  // Guarda el id de la sucursal con la que se comparten clientes, o null
  // si esta sucursal maneja su propia lista de clientes.
  String? _compartirCon;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final grupoActual = widget.sucursal?.grupoClientes;
    if (grupoActual != null && grupoActual != widget.sucursal!.id) {
      // Ya comparte grupo con otra sucursal: la marcamos como preseleccionada
      // si sigue existiendo en la lista.
      final coincidencia = widget.otrasSucursales
          .where((s) => s.grupoClientes == grupoActual)
          .toList();
      if (coincidencia.isNotEmpty) {
        _compartirCon = coincidencia.first.id;
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
      return;
    }

    setState(() => _guardando = true);
    try {
      String? nuevoGrupoClientesId;
      if (_compartirCon != null) {
        final sucursalElegida = widget.otrasSucursales.firstWhere(
          (s) => s.id == _compartirCon,
        );
        nuevoGrupoClientesId = sucursalElegida.grupoClientes;
      }

      final datos = {
        'nombre': nombre,
        'direccion': _direccionController.text.trim(),
        'grupoClientesId': nuevoGrupoClientesId,
      };

      final coleccion = FirebaseFirestore.instance.collection('sucursales');
      if (widget.sucursal == null) {
        await coleccion.add(datos);
      } else {
        await coleccion.doc(widget.sucursal!.id).update(datos);
      }

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
      title: Text(
        widget.sucursal == null ? 'Nueva sucursal' : 'Editar sucursal',
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _direccionController,
              decoration: const InputDecoration(
                labelText: 'Dirección (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _compartirCon,
              decoration: const InputDecoration(
                labelText: 'Compartir clientes con',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Ninguna (clientes propios)'),
                ),
                for (final sucursal in widget.otrasSucursales)
                  DropdownMenuItem(
                    value: sucursal.id,
                    child: Text(sucursal.nombre),
                  ),
              ],
              onChanged: (valor) => setState(() => _compartirCon = valor),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Si un cliente compra fiado en una y en otra, misma ficha y '
                'misma deuda. Útil para locales relacionados (ej: un kiosko '
                'de eventos de la misma cafetería).',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
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
