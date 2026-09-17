import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente.dart';
import '../utils/formato.dart';

class ClientesScreen extends StatelessWidget {
  final String grupoClientesId;
  final bool esAdmin;
  final bool mostrarAppBar;

  const ClientesScreen({
    super.key,
    required this.grupoClientesId,
    this.esAdmin = false,
    this.mostrarAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mostrarAppBar
          ? AppBar(title: const Text('Clientes y crédito'))
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _abrirDetalle(context, null),
                icon: const Icon(Icons.person_add),
                label: const Text('Agregar cliente'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('clientes')
                  .where('grupoClientesId', isEqualTo: grupoClientesId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final clientes =
                    snapshot.data!.docs.map(Cliente.fromDoc).toList()
                      ..sort((a, b) => a.nombre.compareTo(b.nombre));

                if (clientes.isEmpty) {
                  return const Center(
                    child: Text('Aún no hay clientes registrados'),
                  );
                }

                return ListView.builder(
                  itemCount: clientes.length,
                  itemBuilder: (context, indice) {
                    final cliente = clientes[indice];
                    return ListTile(
                      title: Text(cliente.nombre),
                      subtitle: Text(
                        '${cliente.telefono} · '
                        'Límite: ${formatearPesos(cliente.limiteCredito)}',
                      ),
                      trailing: Text(
                        cliente.deuda > 0
                            ? 'Debe ${formatearPesos(cliente.deuda)}'
                            : 'Sin deuda',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cliente.deuda > 0
                              ? Colors.red
                              : Colors.green[700],
                        ),
                      ),
                      onTap: () => _abrirDetalle(context, cliente),
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

  void _abrirDetalle(BuildContext context, Cliente? cliente) {
    showDialog(
      context: context,
      builder: (context) => _DialogoCliente(
        grupoClientesId: grupoClientesId,
        esAdmin: esAdmin,
        cliente: cliente,
      ),
    );
  }
}

class _DialogoCliente extends StatefulWidget {
  final String grupoClientesId;
  final bool esAdmin;
  final Cliente? cliente;

  const _DialogoCliente({
    required this.grupoClientesId,
    required this.esAdmin,
    this.cliente,
  });

  @override
  State<_DialogoCliente> createState() => _DialogoClienteState();
}

class _DialogoClienteState extends State<_DialogoCliente> {
  late final _nombreController = TextEditingController(
    text: widget.cliente?.nombre,
  );
  late final _telefonoController = TextEditingController(
    text: widget.cliente?.telefono,
  );
  late final _direccionController = TextEditingController(
    text: widget.cliente?.direccion,
  );
  late final _limiteController = TextEditingController(
    text: widget.cliente == null || widget.cliente!.limiteCredito == 0
        ? ''
        : formatearPesos(widget.cliente!.limiteCredito).replaceFirst('\$', ''),
  );
  final _abonoController = TextEditingController();
  bool _guardando = false;

  bool get _esNuevo => widget.cliente == null;

  // Un vendedor solo puede registrar abonos sobre un cliente ya existente;
  // editar sus datos (nombre, teléfono, límite) queda para admin, salvo
  // que esté creando uno nuevo (ahí sí necesita cargar todo).
  bool get _puedeEditarDatos => widget.esAdmin || _esNuevo;

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _limiteController.dispose();
    _abonoController.dispose();
    super.dispose();
  }

  Future<void> _guardarDatos() async {
    final nombre = _nombreController.text.trim();
    final telefono = _telefonoController.text.trim();
    final limiteCredito = desformatearPesos(_limiteController.text);

    if (nombre.isEmpty || telefono.isEmpty || limiteCredito <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nombre, teléfono y límite de crédito son obligatorios',
          ),
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final coleccion = FirebaseFirestore.instance.collection('clientes');
      final datos = {
        'nombre': nombre,
        'telefono': telefono,
        'direccion': _direccionController.text.trim(),
        'limiteCredito': limiteCredito,
      };

      if (_esNuevo) {
        await coleccion.add({
          ...datos,
          'grupoClientesId': widget.grupoClientesId,
          'deuda': 0,
        });
      } else {
        await coleccion.doc(widget.cliente!.id).update(datos);
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

  Future<void> _registrarAbono() async {
    final abono = int.tryParse(_abonoController.text) ?? 0;
    if (abono <= 0 || widget.cliente == null) return;

    setState(() => _guardando = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('clientes')
          .doc(widget.cliente!.id);

      await FirebaseFirestore.instance.runTransaction((transaccion) async {
        final snapshot = await transaccion.get(ref);
        final deudaActual = (snapshot.data()?['deuda'] as num?)?.toInt() ?? 0;
        final nuevaDeuda = (deudaActual - abono).clamp(0, deudaActual);
        transaccion.update(ref, {'deuda': nuevaDeuda});
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo registrar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esNuevo ? 'Nuevo cliente' : widget.cliente!.nombre),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreController,
              enabled: _puedeEditarDatos,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonoController,
              enabled: _puedeEditarDatos,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _limiteController,
              enabled: _puedeEditarDatos,
              keyboardType: TextInputType.number,
              inputFormatters: [InputFormatoMiles()],
              decoration: const InputDecoration(
                labelText: 'Límite de crédito',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _direccionController,
              enabled: _puedeEditarDatos,
              decoration: const InputDecoration(
                labelText: 'Dirección (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (!_esNuevo) ...[
              const Divider(height: 32),
              Text(
                'Deuda actual: ${formatearPesos(widget.cliente!.deuda)} de '
                '${formatearPesos(widget.cliente!.limiteCredito)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _abonoController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Registrar abono',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _guardando ? null : _registrarAbono,
                    child: const Text('Abonar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        if (_puedeEditarDatos)
          FilledButton(
            onPressed: _guardando ? null : _guardarDatos,
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
