import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/movimientos_stock.dart';
import '../theme/marca.dart';

class HistorialStockScreen extends StatelessWidget {
  /// Sin sucursal se muestran los movimientos de todas.
  final String? sucursalId;
  final Map<String, String> nombresSucursal;

  const HistorialStockScreen({
    super.key,
    this.sucursalId,
    this.nombresSucursal = const {},
  });

  String _formatearFecha(DateTime fecha) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de stock')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: sucursalId == null
            ? FirebaseFirestore.instance
                  .collection('movimientosStock')
                  .snapshots()
            : FirebaseFirestore.instance
                  .collection('movimientosStock')
                  .where('sucursalId', isEqualTo: sucursalId)
                  .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('No se pudo cargar: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // La fecha es null un instante mientras el servidor no la asigna:
          // ese movimiento es el más reciente, así que va primero.
          DateTime fechaDe(Map<String, dynamic> datos) =>
              (datos['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();

          final movimientos = snapshot.data!.docs.map((d) => d.data()).toList()
            ..sort((a, b) => fechaDe(b).compareTo(fechaDe(a)));

          if (movimientos.isEmpty) {
            return const Center(child: Text('Aún no hay movimientos de stock'));
          }

          return ListView.separated(
            itemCount: movimientos.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, indice) {
              final datos = movimientos[indice];
              final cantidad = (datos['cantidad'] as num?)?.toInt() ?? 0;
              final tipo = TipoMovimientoStock.values.firstWhere(
                (t) => t.name == datos['tipo'],
                orElse: () => TipoMovimientoStock.ajuste,
              );

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (cantidad >= 0 ? Marca.exito : Marca.peligro)
                      .withValues(alpha: 0.16),
                  child: Text(
                    cantidad > 0 ? '+$cantidad' : '$cantidad',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cantidad >= 0 ? Marca.exito : Marca.peligro,
                    ),
                  ),
                ),
                title: Text('${datos['productoNombre']}'),
                subtitle: Text(
                  '${tipo.etiqueta} · ${datos['usuarioNombre']} · '
                  '${sucursalId == null ? '${nombresSucursal[datos['sucursalId']] ?? 'Sucursal'} · ' : ''}'
                  '${_formatearFecha(fechaDe(datos))}',
                ),
                trailing: Text(
                  '${datos['stockAnterior']} → ${datos['stockNuevo']}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
