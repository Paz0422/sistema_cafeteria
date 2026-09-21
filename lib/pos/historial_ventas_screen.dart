import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/cambio_venta.dart';
import '../utils/formato.dart';
import 'dialogo_cambio.dart';
import '../theme/marca.dart';

class HistorialVentasScreen extends StatelessWidget {
  final String turnoId;
  final String sucursalId;
  final String vendedorNombre;
  final bool esAdmin;
  final bool mostrarAppBar;

  /// Texto de ayuda bajo el título (por ejemplo, cuando se abre para hacer un
  /// cambio de producto).
  final String? ayuda;

  const HistorialVentasScreen({
    super.key,
    required this.turnoId,
    required this.sucursalId,
    required this.vendedorNombre,
    this.esAdmin = false,
    this.mostrarAppBar = true,
    this.ayuda,
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
          if (ayuda != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  ayuda!,
                  style: const TextStyle(color: Marca.textoSuave, fontSize: 13),
                ),
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
        final docs = snapshot.data!.docs;
        final ventas = docs.where((d) => d.data()['esCambio'] != true).toList()
          ..sort((a, b) {
            final fechaA = (a.data()['fecha'] as Timestamp?)?.toDate();
            final fechaB = (b.data()['fecha'] as Timestamp?)?.toDate();
            if (fechaA == null) return -1;
            if (fechaB == null) return 1;
            return fechaB.compareTo(fechaA);
          });

        // Los cambios son registros aparte que apuntan a su venta original.
        final cambiosDe = <String, List<Map<String, dynamic>>>{};
        for (final d in docs.where((d) => d.data()['esCambio'] == true)) {
          final original = d.data()['ventaOriginalId'] as String?;
          if (original != null) {
            cambiosDe.putIfAbsent(original, () => []).add(d.data());
          }
        }

        if (ventas.isEmpty) {
          return const Center(
            child: Text('Todavía no registras ventas en este turno'),
          );
        }

        List<Map<String, dynamic>> itemsDe(Map<String, dynamic> datos) =>
            ((datos['items'] as List?) ?? const [])
                .cast<Map<String, dynamic>>();

        return ListView.builder(
          itemCount: ventas.length,
          itemBuilder: (context, indice) {
            final ventaDoc = ventas[indice];
            final datos = ventaDoc.data();
            final cambios = cambiosDe[ventaDoc.id] ?? const [];
            final totalOriginal = (datos['total'] as num?)?.toInt() ?? 0;
            // Lo que la venta vale hoy: el total original más lo que sumaron
            // o restaron sus cambios.
            final total = cambios.fold<int>(
              totalOriginal,
              (suma, c) => suma + ((c['total'] as num?)?.toInt() ?? 0),
            );
            final metodo = datos['metodoPago'] as String? ?? '';
            final clienteNombre = datos['clienteNombre'] as String?;
            final fecha = (datos['fecha'] as Timestamp?)?.toDate();
            final cancelada = datos['cancelada'] as bool? ?? false;
            final items = itemsNetos(itemsDe(datos), [
              for (final c in cambios) itemsDe(c),
            ]);

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
                  if (cambios.isNotEmpty) 'CON CAMBIO',
                  _etiquetaMetodo(metodo),
                  if (fecha != null)
                    '${fecha.hour.toString().padLeft(2, '0')}:'
                        '${fecha.minute.toString().padLeft(2, '0')}',
                  ?clienteNombre,
                ].join(' · '),
                style: cancelada
                    ? const TextStyle(color: Marca.peligro)
                    : cambios.isNotEmpty
                    ? const TextStyle(color: Marca.dorado)
                    : null,
              ),
              children: [
                ...items.map(
                  (item) => ListTile(
                    dense: true,
                    title: Text(item.nombre),
                    trailing: Text(
                      '${item.cantidad} × ${formatearPesos(item.precioUnitario)}',
                    ),
                  ),
                ),
                for (final c in cambios) _FilaCambio(datos: c),
                if (!cancelada)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (items.isNotEmpty)
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _cambiarProducto(context, ventaDoc, items),
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Cambiar producto'),
                          ),
                        // Una venta con cambios ya no se cancela entera: el
                        // stock y la caja ya se movieron con cada cambio.
                        if (cambios.isEmpty)
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
    List<ItemVenta> items,
  ) async {
    final datos = ventaDoc.data();
    final hecho = await showDialog<bool>(
      context: context,
      builder: (context) => DialogoCambio(
        ventaId: ventaDoc.id,
        turnoId: turnoId,
        sucursalId: sucursalId,
        vendedorNombre: vendedorNombre,
        metodoOriginal: datos['metodoPago'] as String? ?? '',
        clienteId: datos['clienteId'] as String?,
        clienteNombre: datos['clienteNombre'] as String?,
        items: items,
      ),
    );
    if (hecho == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cambio registrado')));
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

/// Una línea del detalle de una venta que describe un cambio ya hecho.
class _FilaCambio extends StatelessWidget {
  final Map<String, dynamic> datos;

  const _FilaCambio({required this.datos});

  @override
  Widget build(BuildContext context) {
    final items = ((datos['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final devuelto = items.isNotEmpty ? items.first['nombre'] : '';
    final nuevo = items.length > 1 ? items[1]['nombre'] : '';
    final unidades = items.length > 1
        ? (items[1]['cantidad'] as num?)?.toInt() ?? 1
        : 1;
    final diferencia = (datos['total'] as num?)?.toInt() ?? 0;
    final medio = switch (datos['metodoPago']) {
      'tarjeta' => 'tarjeta',
      'credito' => 'a la deuda',
      _ => 'efectivo',
    };

    return ListTile(
      dense: true,
      leading: const Icon(Icons.swap_horiz, size: 18, color: Marca.dorado),
      title: Text('$devuelto → $nuevo (x$unidades)'),
      trailing: Text(
        diferencia == 0
            ? 'Sin diferencia'
            : diferencia > 0
            ? 'Cobrado ${formatearPesos(diferencia)} ($medio)'
            : 'Devuelto ${formatearPesos(-diferencia)} ($medio)',
        style: TextStyle(
          fontSize: 12,
          color: diferencia < 0 ? Marca.exito : Marca.textoSuave,
        ),
      ),
    );
  }
}
