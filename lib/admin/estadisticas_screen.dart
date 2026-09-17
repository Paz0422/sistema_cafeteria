import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/sucursal.dart';
import '../utils/formato.dart';

const _umbralStockBajo = 5;

class _AlertaStock {
  final Producto producto;
  final String sucursalNombre;
  final int stock;

  const _AlertaStock({
    required this.producto,
    required this.sucursalNombre,
    required this.stock,
  });
}

class EstadisticasScreen extends StatelessWidget {
  final bool mostrarAppBar;

  const EstadisticasScreen({super.key, this.mostrarAppBar = true});

  DateTime get _inicioDeHoy {
    final ahora = DateTime.now();
    return DateTime(ahora.year, ahora.month, ahora.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mostrarAppBar ? AppBar(title: const Text('Estadísticas')) : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('sucursales').snapshots(),
        builder: (context, sucursalesSnap) {
          final sucursales =
              sucursalesSnap.data?.docs.map(Sucursal.fromDoc).toList() ?? [];

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('ventas')
                .where(
                  'fecha',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(_inicioDeHoy),
                )
                .snapshots(),
            builder: (context, ventasSnap) {
              if (!ventasSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var totalHoy = 0;
              final porSucursal = <String, int>{};
              final porProducto = <String, int>{};

              for (final doc in ventasSnap.data!.docs) {
                final datos = doc.data();
                if (datos['cancelada'] == true) continue;

                final total = (datos['total'] as num?)?.toInt() ?? 0;
                final sucursalId = datos['sucursalId'] as String? ?? '';
                totalHoy += total;
                porSucursal[sucursalId] =
                    (porSucursal[sucursalId] ?? 0) + total;

                for (final item in (datos['items'] as List? ?? [])) {
                  final nombre = item['nombre'] as String? ?? '';
                  final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;
                  porProducto[nombre] = (porProducto[nombre] ?? 0) + cantidad;
                }
              }

              final rankingProductos = porProducto.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('turnos')
                    .where('estado', isEqualTo: 'abierto')
                    .snapshots(),
                builder: (context, turnosSnap) {
                  final turnosAbiertos = turnosSnap.data?.docs.length ?? 0;

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('productos')
                        .snapshots(),
                    builder: (context, productosSnap) {
                      final productos =
                          productosSnap.data?.docs
                              .map(Producto.fromDoc)
                              .toList() ??
                          [];

                      // El stock es por sucursal, así que la alerta se arma
                      // revisando cada combinación producto+sucursal por
                      // separado (un mismo producto puede estar bien de
                      // stock en una sucursal y bajo en otra).
                      final stockBajo = <_AlertaStock>[];
                      for (final producto in productos) {
                        if (!producto.controlaStock) continue;
                        for (final sucursal in sucursales) {
                          final stock = producto.stockEn(sucursal.id);
                          if (stock <= _umbralStockBajo) {
                            stockBajo.add(
                              _AlertaStock(
                                producto: producto,
                                sucursalNombre: sucursal.nombre,
                                stock: stock,
                              ),
                            );
                          }
                        }
                      }
                      stockBajo.sort((a, b) => a.stock.compareTo(b.stock));

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('clientes')
                            .snapshots(),
                        builder: (context, clientesSnap) {
                          final clientes =
                              clientesSnap.data?.docs
                                  .map(Cliente.fromDoc)
                                  .toList() ??
                              [];
                          final conDeuda =
                              clientes.where((c) => c.deuda > 0).toList()
                                ..sort((a, b) => b.deuda.compareTo(a.deuda));

                          return _Contenido(
                            sucursales: sucursales,
                            totalHoy: totalHoy,
                            turnosAbiertos: turnosAbiertos,
                            porSucursal: porSucursal,
                            rankingProductos: rankingProductos,
                            stockBajo: stockBajo,
                            conDeuda: conDeuda,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  final List<Sucursal> sucursales;
  final int totalHoy;
  final int turnosAbiertos;
  final Map<String, int> porSucursal;
  final List<MapEntry<String, int>> rankingProductos;
  final List<_AlertaStock> stockBajo;
  final List<Cliente> conDeuda;

  const _Contenido({
    required this.sucursales,
    required this.totalHoy,
    required this.turnosAbiertos,
    required this.porSucursal,
    required this.rankingProductos,
    required this.stockBajo,
    required this.conDeuda,
  });

  String _nombreSucursal(String id) {
    for (final s in sucursales) {
      if (s.id == id) return s.nombre;
    }
    return 'Sin sucursal';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Resumen general',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _TarjetaStat(
              icono: Icons.trending_up,
              titulo: 'Ventas de hoy',
              valor: formatearPesos(totalHoy),
            ),
            _TarjetaStat(
              icono: Icons.point_of_sale,
              titulo: 'Turnos abiertos ahora',
              valor: '$turnosAbiertos',
            ),
            _TarjetaStat(
              icono: Icons.storefront,
              titulo: 'Sucursales',
              valor: '${sucursales.length}',
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          'Ventas de hoy por sucursal',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (sucursales.isEmpty)
          const Text('Todavía no has creado ninguna sucursal.')
        else
          Card(
            child: Column(
              children: [
                for (final sucursal in sucursales)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(sucursal.nombre),
                    trailing: Text(
                      formatearPesos(porSucursal[sucursal.id] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth;
            final children = [
              _SeccionProductosMasVendidos(ranking: rankingProductos),
              _SeccionAlertas(
                stockBajo: stockBajo,
                conDeuda: conDeuda,
                nombreSucursal: _nombreSucursal,
              ),
            ];

            if (ancho < 700) {
              return Column(
                children: [
                  children[0],
                  const SizedBox(height: 32),
                  children[1],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 24),
                Expanded(child: children[1]),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TarjetaStat extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;

  const _TarjetaStat({
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icono, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  Text(
                    valor,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeccionProductosMasVendidos extends StatelessWidget {
  final List<MapEntry<String, int>> ranking;

  const _SeccionProductosMasVendidos({required this.ranking});

  @override
  Widget build(BuildContext context) {
    final top = ranking.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Productos más vendidos hoy',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (top.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Todavía no hay ventas registradas hoy'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final entrada in top)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.local_cafe_outlined),
                    title: Text(entrada.key),
                    trailing: Text(
                      '${entrada.value} und.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SeccionAlertas extends StatelessWidget {
  final List<_AlertaStock> stockBajo;
  final List<Cliente> conDeuda;
  final String Function(String id) nombreSucursal;

  const _SeccionAlertas({
    required this.stockBajo,
    required this.conDeuda,
    required this.nombreSucursal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alertas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Stock bajo (≤ $_umbralStockBajo unidades)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        if (stockBajo.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ningún producto con stock bajo'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final alerta in stockBajo)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.warning_amber,
                      color: alerta.stock == 0 ? Colors.red : Colors.orange,
                    ),
                    title: Text(alerta.producto.nombre),
                    subtitle: Text(alerta.sucursalNombre),
                    trailing: Text(
                      'Stock: ${alerta.stock}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Clientes con deuda',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        if (conDeuda.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ningún cliente tiene deuda pendiente'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final cliente in conDeuda.take(8))
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.person,
                      color: cliente.deuda >= cliente.limiteCredito
                          ? Colors.red
                          : Colors.orange,
                    ),
                    title: Text(cliente.nombre),
                    subtitle: cliente.telefono.isEmpty
                        ? null
                        : Text(cliente.telefono),
                    trailing: Text(
                      '${formatearPesos(cliente.deuda)} de '
                      '${formatearPesos(cliente.limiteCredito)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
