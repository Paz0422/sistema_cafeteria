import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/movimientos_stock.dart';

class HistorialStockScreen extends StatelessWidget {
  final String sucursalId;

  const HistorialStockScreen({super.key, required this.sucursalId});

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
        stream: FirebaseFirestore.instance
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
            return const Center(
              child: Text('Aún no hay movimientos de stock en esta sucursal'),
            );
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
                  backgroundColor: cantidad >= 0
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  child: Text(
                    cantidad > 0 ? '+$cantidad' : '$cantidad',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cantidad >= 0
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                    ),
                  ),
                ),
                title: Text('${datos['productoNombre']}'),
                subtitle: Text(
                  '${tipo.etiqueta} · ${datos['usuarioNombre']} · '
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
