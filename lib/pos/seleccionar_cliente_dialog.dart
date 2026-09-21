import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente.dart';
import '../utils/escritura_offline.dart';
import '../utils/formato.dart';

class SeleccionarClienteDialog extends StatefulWidget {
  final String grupoClientesId;

  const SeleccionarClienteDialog({super.key, required this.grupoClientesId});

  @override
  State<SeleccionarClienteDialog> createState() =>
      _SeleccionarClienteDialogState();
}

class _SeleccionarClienteDialogState extends State<SeleccionarClienteDialog> {
  final _busquedaController = TextEditingController();
  final _nombreNuevoController = TextEditingController();
  final _telefonoNuevoController = TextEditingController();
  final _direccionNuevoController = TextEditingController();
  final _limiteNuevoController = TextEditingController();
  bool _creandoNuevo = false;
  bool _guardando = false;

  @override
  void dispose() {
    _busquedaController.dispose();
    _nombreNuevoController.dispose();
    _telefonoNuevoController.dispose();
    _direccionNuevoController.dispose();
    _limiteNuevoController.dispose();
    super.dispose();
  }

  Future<void> _crearCliente() async {
    final nombre = _nombreNuevoController.text.trim();
    final telefono = _telefonoNuevoController.text.trim();
    final limiteCredito = desformatearPesos(_limiteNuevoController.text);

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
      final direccion = _direccionNuevoController.text.trim();
      // Id generado en el equipo: sin internet el cliente queda en cola y se
      // puede usar de inmediato en esta venta.
      final ref = FirebaseFirestore.instance.collection('clientes').doc();
      await esperarConfirmacion(
        ref.set({
          'grupoClientesId': widget.grupoClientesId,
          'nombre': nombre,
          'telefono': telefono,
          'direccion': direccion,
          'limiteCredito': limiteCredito,
          'deuda': 0,
        }),
      );
      if (mounted) {
        Navigator.pop(
          context,
          Cliente(
            id: ref.id,
            grupoClientesId: widget.grupoClientesId,
            nombre: nombre,
            telefono: telefono,
            direccion: direccion,
            limiteCredito: limiteCredito,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar cliente'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: _creandoNuevo ? _formularioNuevoCliente() : _buscadorClientes(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (!_creandoNuevo)
          TextButton(
            onPressed: () => setState(() => _creandoNuevo = true),
            child: const Text('Nuevo cliente'),
          ),
        if (_creandoNuevo)
          FilledButton(
            onPressed: _guardando ? null : _crearCliente,
            child: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Crear y usar'),
          ),
      ],
    );
  }

  Widget _buscadorClientes() {
    return Column(
      children: [
        TextField(
          controller: _busquedaController,
          decoration: const InputDecoration(
            labelText: 'Buscar por nombre',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('clientes')
                .where('grupoClientesId', isEqualTo: widget.grupoClientesId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final busqueda = _busquedaController.text.trim().toLowerCase();
              final clientes =
                  snapshot.data!.docs
                      .map(Cliente.fromDoc)
                      .where((c) => c.nombre.toLowerCase().contains(busqueda))
                      .toList()
                    ..sort((a, b) => a.nombre.compareTo(b.nombre));

              if (clientes.isEmpty) {
                return const Center(child: Text('Sin clientes que coincidan'));
              }

              return ListView.builder(
                itemCount: clientes.length,
                itemBuilder: (context, indice) {
                  final cliente = clientes[indice];
                  return ListTile(
                    title: Text(cliente.nombre),
                    subtitle: cliente.deuda > 0
                        ? Text('Debe: ${formatearPesos(cliente.deuda)}')
                        : null,
                    onTap: () => Navigator.pop(context, cliente),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _formularioNuevoCliente() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nombreNuevoController,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telefonoNuevoController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limiteNuevoController,
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
            controller: _direccionNuevoController,
            decoration: const InputDecoration(
              labelText: 'Dirección (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
