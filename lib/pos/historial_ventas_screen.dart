import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item_carrito.dart';
import '../models/producto.dart';
import '../utils/formato.dart';
import 'seleccionar_producto_dialog.dart';
import '../theme/marca.dart';

class _StockInsuficienteCambio implements Exception {
  final String nombre;
  final int disponible;

  _StockInsuficienteCambio(this.nombre, this.disponible);
}

class HistorialVentasScreen extends StatelessWidget {
  final String turnoId;
  final String sucursalId;
  final bool esAdmin;
  final bool mostrarAppBar;

  const HistorialVentasScreen({
    super.key,
    required this.turnoId,
    required this.sucursalId,
    this.esAdmin = false,
    this.mostrarAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final vendedorUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: mostrarAppBar
          ? AppBar(title: const Text('Historial de ventas del turno'))
          : null,
      body: Column(
        children: [
          if (!mostrarAppBar)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Historial de ventas del turno',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          Expanded(child: _listaVentas(vendedorUid)),
        ],
      ),
    );
  }

  Widget _listaVentas(String? vendedorUid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ventas')
          .where('turnoId', isEqualTo: turnoId)
          .where('vendedorUid', isEqualTo: vendedorUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Se ordena en el cliente (más reciente primero) para no depender
        // de un índice compuesto en Firestore.
        final ventas = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final fechaA = (a.data()['fecha'] as Timestamp?)?.toDate();
            final fechaB = (b.data()['fecha'] as Timestamp?)?.toDate();
            if (fechaA == null) return -1;
            if (fechaB == null) return 1;
            return fechaB.compareTo(fechaA);
          });

        if (ventas.isEmpty) {
          return const Center(
            child: Text('Todavía no registras ventas en este turno'),
          );
        }

        return ListView.builder(
          itemCount: ventas.length,
          itemBuilder: (context, indice) {
            final ventaDoc = ventas[indice];
            final datos = ventaDoc.data();
            final total = (datos['total'] as num?)?.toInt() ?? 0;
            final metodo = datos['metodoPago'] as String? ?? '';
            final clienteNombre = datos['clienteNombre'] as String?;
            final fecha = (datos['fecha'] as Timestamp?)?.toDate();
            final items = (datos['items'] as List?) ?? [];
            final cancelada = datos['cancelada'] as bool? ?? false;

            return ExpansionTile(
              title: Text(
                formatearPesos(total),
                style: cancelada
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              subtitle: Text(
                [
                  if (cancelada) 'CANCELADA',
                  _etiquetaMetodo(metodo),
                  if (fecha != null)
                    '${fecha.hour.toString().padLeft(2, '0')}:'
                        '${fecha.minute.toString().padLeft(2, '0')}',
                  ?clienteNombre,
                ].join(' · '),
                style: cancelada ? TextStyle(color: Marca.peligro) : null,
              ),
              children: [
                ...items.map(
                  (item) => ListTile(
                    dense: true,
                    title: Text('${item['nombre']}'),
                    trailing: Text(
                      '${item['cantidad']} × '
                      '${formatearPesos((item['precioUnitario'] as num).toInt())}',
                    ),
                  ),
                ),
                if (!cancelada)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Corregir una venta cambia sus montos, así que solo
                        // lo permiten las reglas de Firestore al admin.
                        if (esAdmin) ...[
                          TextButton.icon(
                            onPressed: () =>
                                _cambiarProducto(context, ventaDoc),
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Cambiar producto'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        TextButton.icon(
                          onPressed: () => _cancelarVenta(context, ventaDoc),
                          icon: const Icon(
                            Icons.cancel_outlined,
                            size: 18,
                            color: Marca.peligro,
                          ),
                          label: const Text(
                            'Cancelar venta',
                            style: TextStyle(color: Marca.peligro),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelarVenta(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> ventaDoc,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar venta'),
        content: const Text(
          'Se devolverá el stock de los productos y, si fue a crédito, se le '
          'quitará la deuda al cliente. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar venta'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    final datos = ventaDoc.data();
    final items = (datos['items'] as List).cast<Map<String, dynamic>>();
    final metodo = datos['metodoPago'] as String?;
    final clienteId = datos['clienteId'] as String?;
    final total = (datos['total'] as num?)?.toInt() ?? 0;
    final sucursalId = datos['sucursalId'] as String? ?? '';
    final firestore = FirebaseFirestore.instance;

    try {
      await firestore.runTransaction((transaccion) async {
        final refsProductos = [
          for (final item in items)
            firestore.collection('productos').doc(item['productoId'] as String),
        ];

        final snapshotsProductos = await Future.wait([
          for (final ref in refsProductos) transaccion.get(ref),
        ]);

        DocumentReference<Map<String, dynamic>>? clienteRef;
        DocumentSnapshot<Map<String, dynamic>>? clienteSnap;
        if (metodo == 'credito' && clienteId != null) {
          clienteRef = firestore.collection('clientes').doc(clienteId);
          clienteSnap = await transaccion.get(clienteRef);
        }

        for (var i = 0; i < items.length; i++) {
          final datosProducto = snapshotsProductos[i].data();
          if (datosProducto == null) continue;
          if (!(datosProducto['controlaStock'] as bool? ?? false)) continue;

          final stockPorSucursal =
              datosProducto['stockPorSucursal'] as Map<String, dynamic>?;
          final stockActual =
              (stockPorSucursal?[sucursalId] as num?)?.toInt() ?? 0;
          final cantidad = (items[i]['cantidad'] as num).toInt();
          transaccion.update(refsProductos[i], {
            'stockPorSucursal.$sucursalId': stockActual + cantidad,
          });
        }

        if (clienteRef != null && clienteSnap != null) {
          final deudaActual =
              (clienteSnap.data()?['deuda'] as num?)?.toInt() ?? 0;
          final nuevaDeuda = deudaActual - total;
          transaccion.update(clienteRef, {
            'deuda': nuevaDeuda < 0 ? 0 : nuevaDeuda,
          });
        }

        transaccion.update(ventaDoc.reference, {
          'cancelada': true,
          'fechaCancelacion': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo cancelar: $e')));
      }
    }
  }

  Future<void> _cambiarProducto(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> ventaDoc,
  ) async {
    final datos = ventaDoc.data();
    final items = (datos['items'] as List).cast<Map<String, dynamic>>();
    final sucursalId = datos['sucursalId'] as String? ?? '';

    final indiceElegido = items.length == 1
        ? 0
        : await showDialog<int>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('¿Qué producto quieres cambiar?'),
              children: [
                for (var i = 0; i < items.length; i++)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, i),
                    child: Text(
                      '${items[i]['nombre']} (x${items[i]['cantidad']})',
                    ),
                  ),
              ],
            ),
          );
    if (indiceElegido == null || !context.mounted) return;

    final nuevoProducto = await showDialog<Producto>(
      context: context,
      builder: (context) => SeleccionarProductoDialog(sucursalId: sucursalId),
    );
    if (nuevoProducto == null || !context.mounted) return;

    final itemViejo = items[indiceElegido];
    final productoViejoId = itemViejo['productoId'] as String;
    final cantidad = (itemViejo['cantidad'] as num).toInt();

    if (productoViejoId == nuevoProducto.id) return;

    final firestore = FirebaseFirestore.instance;
    final refViejo = firestore.collection('productos').doc(productoViejoId);
    final refNuevo = firestore.collection('productos').doc(nuevoProducto.id);
    final metodo = datos['metodoPago'] as String?;
    final clienteId = datos['clienteId'] as String?;
    final totalViejo = (datos['total'] as num?)?.toInt() ?? 0;
    final montoEfectivoViejo = (datos['montoEfectivo'] as num?)?.toInt() ?? 0;

    try {
      await firestore.runTransaction((transaccion) async {
        final snapViejo = await transaccion.get(refViejo);
        final snapNuevo = await transaccion.get(refNuevo);

        DocumentReference<Map<String, dynamic>>? clienteRef;
        DocumentSnapshot<Map<String, dynamic>>? clienteSnap;
        if (metodo == 'credito' && clienteId != null) {
          clienteRef = firestore.collection('clientes').doc(clienteId);
          clienteSnap = await transaccion.get(clienteRef);
        }

        final datosViejo = snapViejo.data();
        if (datosViejo != null &&
            (datosViejo['controlaStock'] as bool? ?? false)) {
          final stockPorSucursalViejo =
              datosViejo['stockPorSucursal'] as Map<String, dynamic>?;
          final stockViejo =
              (stockPorSucursalViejo?[sucursalId] as num?)?.toInt() ?? 0;
          transaccion.update(refViejo, {
            'stockPorSucursal.$sucursalId': stockViejo + cantidad,
          });
        }

        final datosNuevo = snapNuevo.data();
        if (datosNuevo != null &&
            (datosNuevo['controlaStock'] as bool? ?? false)) {
          final stockPorSucursalNuevo =
              datosNuevo['stockPorSucursal'] as Map<String, dynamic>?;
          final stockNuevo =
              (stockPorSucursalNuevo?[sucursalId] as num?)?.toInt() ?? 0;
          if (stockNuevo < cantidad) {
            throw _StockInsuficienteCambio(nuevoProducto.nombre, stockNuevo);
          }
          transaccion.update(refNuevo, {
            'stockPorSucursal.$sucursalId': stockNuevo - cantidad,
          });
        }

        final nuevoSubtotal = ItemCarrito(
          producto: nuevoProducto,
          cantidad: cantidad,
        ).subtotal;
        final nuevosItems = List<Map<String, dynamic>>.from(items);
        nuevosItems[indiceElegido] = {
          'productoId': nuevoProducto.id,
          'nombre': nuevoProducto.nombre,
          'cantidad': cantidad,
          'precioUnitario': nuevoProducto.precio,
          'subtotal': nuevoSubtotal,
        };
        final nuevoTotal = nuevosItems.fold<int>(
          0,
          (suma, item) => suma + (item['subtotal'] as int),
        );
        final diferencia = nuevoTotal - totalViejo;

        final actualizacion = <String, dynamic>{
          'items': nuevosItems,
          'total': nuevoTotal,
          'editada': true,
          'fechaEdicion': FieldValue.serverTimestamp(),
        };

        if (metodo == 'efectivo') {
          actualizacion['montoEfectivo'] = nuevoTotal;
        } else if (metodo == 'mixto') {
          actualizacion['montoEfectivo'] = montoEfectivoViejo + diferencia;
        }

        if (clienteRef != null && clienteSnap != null) {
          final deudaActual =
              (clienteSnap.data()?['deuda'] as num?)?.toInt() ?? 0;
          final nuevaDeuda = deudaActual + diferencia;
          transaccion.update(clienteRef, {
            'deuda': nuevaDeuda < 0 ? 0 : nuevaDeuda,
          });
        }

        transaccion.update(ventaDoc.reference, actualizacion);
      });
    } on _StockInsuficienteCambio catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sin stock suficiente de ${e.nombre}. Disponible: ${e.disponible}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cambiar el producto: $e')),
        );
      }
    }
  }

  String _etiquetaMetodo(String metodo) => switch (metodo) {
    'efectivo' => 'Efectivo',
    'tarjeta' => 'Tarjeta',
    'mixto' => 'Mixto',
    'credito' => 'Crédito',
    _ => metodo,
  };
}
