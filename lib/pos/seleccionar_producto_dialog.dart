import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producto.dart';
import '../utils/formato.dart';

class SeleccionarProductoDialog extends StatefulWidget {
  final String sucursalId;

  const SeleccionarProductoDialog({super.key, required this.sucursalId});

  @override
  State<SeleccionarProductoDialog> createState() =>
      _SeleccionarProductoDialogState();
}

class _SeleccionarProductoDialogState extends State<SeleccionarProductoDialog> {
  final _busquedaController = TextEditingController();

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir producto de reemplazo'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
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
                    .collection('productos')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final busqueda = _busquedaController.text
                      .trim()
                      .toLowerCase();
                  final productos =
                      snapshot.data!.docs
                          .map(Producto.fromDoc)
                          .where(
                            (p) => p.nombre.toLowerCase().contains(busqueda),
                          )
                          .toList()
                        ..sort((a, b) => a.nombre.compareTo(b.nombre));

                  if (productos.isEmpty) {
                    return const Center(
                      child: Text('Sin productos que coincidan'),
                    );
                  }

                  return ListView.builder(
                    itemCount: productos.length,
                    itemBuilder: (context, indice) {
                      final producto = productos[indice];
                      return ListTile(
                        title: Text(producto.nombre),
                        subtitle: Text(
                          producto.controlaStock
                              ? '${formatearPesos(producto.precio)} · '
                                    'Stock aquí: ${producto.stockEn(widget.sucursalId)}'
                              : formatearPesos(producto.precio),
                        ),
                        onTap: () => Navigator.pop(context, producto),
                      );
                    },
                  );
                },
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
      ],
    );
  }
}
