import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producto.dart';
import '../utils/escritura_offline.dart';
import '../utils/movimientos_stock.dart';

/// Suma mercadería que llegó al stock de una sucursal. Al guardar devuelve la
/// cantidad agregada (o null si se cancela).
///
/// Lo usan el catálogo del punto de venta y la venta misma, cuando se escanea
/// un producto sin stock ([aviso] explica por qué se abrió).
class DialogoAjusteStock extends StatefulWidget {
  final String sucursalId;
  final String usuarioNombre;
  final Producto producto;
  final String? aviso;

  const DialogoAjusteStock({
    super.key,
    required this.sucursalId,
    required this.usuarioNombre,
    required this.producto,
    this.aviso,
  });

  @override
  State<DialogoAjusteStock> createState() => _DialogoAjusteStockState();
}

class _DialogoAjusteStockState extends State<DialogoAjusteStock> {
  final _cantidadController = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final cantidadAgregar = int.tryParse(_cantidadController.text);
    if (cantidadAgregar == null || cantidadAgregar <= 0) return;

    setState(() => _guardando = true);
    try {
      // Se suma con increment() en vez de escribir "stock visto + cantidad":
      // así una venta que ocurra mientras este diálogo está abierto no se
      // pisa.
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance
            .collection('productos')
            .doc(widget.producto.id),
        {
          'stockPorSucursal.${widget.sucursalId}': FieldValue.increment(
            cantidadAgregar,
          ),
        },
      );
      registrarMovimientoStock(
        batch,
        productoId: widget.producto.id,
        productoNombre: widget.producto.nombre,
        sucursalId: widget.sucursalId,
        tipo: TipoMovimientoStock.ingreso,
        cantidad: cantidadAgregar,
        stockAnterior: widget.producto.stockEn(widget.sucursalId),
        usuarioNombre: widget.usuarioNombre,
      );
      await esperarConfirmacion(batch.commit());

      if (mounted) Navigator.pop(context, cantidadAgregar);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Agregar stock: ${widget.producto.nombre}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.aviso != null) ...[
            Text(widget.aviso!),
            const SizedBox(height: 8),
          ],
          Text(
            'Stock actual en esta sucursal: '
            '${widget.producto.stockEn(widget.sucursalId)}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cantidadController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            onSubmitted: (_) => _guardando ? null : _guardar(),
            decoration: const InputDecoration(
              labelText: 'Cantidad que llegó',
              border: OutlineInputBorder(),
              prefixText: '+ ',
            ),
          ),
        ],
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
