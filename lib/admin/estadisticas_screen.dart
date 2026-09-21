import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/sucursal.dart';
import '../utils/formato.dart';
import '../utils/resumen_ventas.dart';
import '../theme/marca.dart';

const _umbralStockBajo = 5;

const _nombresDias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _nombresMeses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _dosDigitos(int n) => n.toString().padLeft(2, '0');

String _formatearDia(DateTime d) =>
    '${_dosDigitos(d.day)}/${_dosDigitos(d.month)}/${d.year}';

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

class EstadisticasScreen extends StatefulWidget {
  final bool mostrarAppBar;

  const EstadisticasScreen({super.key, this.mostrarAppBar = true});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  // Los streams se crean una sola vez: si se crearan dentro de build(), cada
  // actualización volvería a suscribirse a todo.
  final _sucursalesStream = FirebaseFirestore.instance
      .collection('sucursales')
      .snapshots();
  final _turnosAbiertosStream = FirebaseFirestore.instance
      .collection('turnos')
      .where('estado', isEqualTo: 'abierto')
      .snapshots();
  final _productosStream = FirebaseFirestore.instance
      .collection('productos')
      .snapshots();
  final _clientesStream = FirebaseFirestore.instance
      .collection('clientes')
      .snapshots();

  PeriodoReporte _periodo = PeriodoReporte.hoy;
  DateTimeRange _rango = rangoDe(PeriodoReporte.hoy);
  String? _sucursalFiltro;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _ventasStream =
      _crearVentasStream();

  Stream<QuerySnapshot<Map<String, dynamic>>> _crearVentasStream() {
    final finExclusivo = DateTime(
      _rango.end.year,
      _rango.end.month,
      _rango.end.day + 1,
    );
    return FirebaseFirestore.instance
        .collection('ventas')
        .where(
          'fecha',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_rango.start),
        )
        .where('fecha', isLessThan: Timestamp.fromDate(finExclusivo))
        .snapshots();
  }

  void _elegirPeriodo(PeriodoReporte periodo) {
    setState(() {
      _periodo = periodo;
      _rango = rangoDe(periodo);
      _ventasStream = _crearVentasStream();
    });
  }

  Future<void> _elegirRangoPersonalizado() async {
    final hoy = soloDia(DateTime.now());
    final elegido = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: hoy,
      initialDateRange: _rango,
      helpText: 'Elige el rango de fechas',
      saveText: 'Aplicar',
    );
    if (elegido == null || !mounted) return;

    setState(() {
      _periodo = PeriodoReporte.personalizado;
      _rango = DateTimeRange(
        start: soloDia(elegido.start),
        end: soloDia(elegido.end),
      );
      _ventasStream = _crearVentasStream();
    });
  }

  ResumenVentas _resumir(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? sucursalId,
  ) => resumirVentas(
    docs.map((doc) => doc.data()),
    sucursalId: sucursalId,
    porMes: agruparPorMes(_rango),
  );

  String get _etiquetaRango {
    if (_rango.start == _rango.end) return _formatearDia(_rango.start);
    return '${_formatearDia(_rango.start)} – ${_formatearDia(_rango.end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.mostrarAppBar
          ? AppBar(title: const Text('Estadísticas'))
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _sucursalesStream,
        builder: (context, sucursalesSnap) {
          final sucursales =
              (sucursalesSnap.data?.docs.map(Sucursal.fromDoc).toList() ?? [])
                ..sort((a, b) => a.nombre.compareTo(b.nombre));

          // Si la sucursal filtrada se borró, se vuelve a "todas".
          final filtro = sucursales.any((s) => s.id == _sucursalFiltro)
              ? _sucursalFiltro
              : null;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _ventasStream,
            builder: (context, ventasSnap) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _BarraFiltros(
                    periodo: _periodo,
                    etiquetaRango: _etiquetaRango,
                    onPeriodo: _elegirPeriodo,
                    onPersonalizado: _elegirRangoPersonalizado,
                    sucursales: sucursales,
                    sucursalId: filtro,
                    onSucursal: (id) => setState(() => _sucursalFiltro = id),
                  ),
                  const SizedBox(height: 24),
                  if (ventasSnap.hasError)
                    Text(
                      'No se pudieron cargar las ventas: ${ventasSnap.error}',
                    )
                  else if (!ventasSnap.hasData)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _ContenidoVentas(
                      resumen: _resumir(ventasSnap.data!.docs, filtro),
                      sucursales: sucursales,
                      sucursalFiltrada: filtro,
                      rango: _rango,
                    ),
                  const SizedBox(height: 32),
                  const _TituloSeccion('Estado actual'),
                  const SizedBox(height: 8),
                  _PanelEstadoActual(
                    turnosStream: _turnosAbiertosStream,
                    productosStream: _productosStream,
                    clientesStream: _clientesStream,
                    sucursales: sucursales,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _BarraFiltros extends StatelessWidget {
  final PeriodoReporte periodo;
  final String etiquetaRango;
  final ValueChanged<PeriodoReporte> onPeriodo;
  final VoidCallback onPersonalizado;
  final List<Sucursal> sucursales;
  final String? sucursalId;
  final ValueChanged<String?> onSucursal;

  const _BarraFiltros({
    required this.periodo,
    required this.etiquetaRango,
    required this.onPeriodo,
    required this.onPersonalizado,
    required this.sucursales,
    required this.sucursalId,
    required this.onSucursal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final p in PeriodoReporte.values)
              ChoiceChip(
                label: Text(p.etiqueta),
                avatar: p == PeriodoReporte.personalizado
                    ? const Icon(Icons.date_range, size: 18)
                    : null,
                selected: p == periodo,
                onSelected: (_) => p == PeriodoReporte.personalizado
                    ? onPersonalizado()
                    : onPeriodo(p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              etiquetaRango,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                initialValue: sucursalId,
                decoration: const InputDecoration(
                  labelText: 'Sucursal',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Todas las sucursales'),
                  ),
                  for (final s in sucursales)
                    DropdownMenuItem(value: s.id, child: Text(s.nombre)),
                ],
                onChanged: onSucursal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContenidoVentas extends StatelessWidget {
  final ResumenVentas resumen;
  final List<Sucursal> sucursales;
  final String? sucursalFiltrada;
  final DateTimeRange rango;

  const _ContenidoVentas({
    required this.resumen,
    required this.sucursales,
    required this.sucursalFiltrada,
    required this.rango,
  });

  @override
  Widget build(BuildContext context) {
    final ranking = resumen.unidadesPorProducto.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final porMes = agruparPorMes(rango);
    final visibles = sucursalFiltrada == null
        ? sucursales
        : sucursales.where((s) => s.id == sucursalFiltrada).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _TarjetaStat(
              icono: Icons.trending_up,
              titulo: 'Total vendido',
              valor: formatearPesos(resumen.total),
            ),
            _TarjetaStat(
              icono: Icons.receipt_long,
              titulo: 'Cantidad de ventas',
              valor: '${resumen.cantidadVentas}',
            ),
            _TarjetaStat(
              icono: Icons.confirmation_number_outlined,
              titulo: 'Ticket promedio',
              valor: formatearPesos(resumen.ticketPromedio),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _DosColumnas(
          izquierda: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TituloSeccion('Por método de pago'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _FilaMonto(
                      icono: Icons.payments_outlined,
                      titulo: 'Efectivo',
                      monto: resumen.vendidoEfectivo,
                    ),
                    _FilaMonto(
                      icono: Icons.credit_card,
                      titulo: 'Tarjeta',
                      monto: resumen.vendidoTarjeta,
                    ),
                    _FilaMonto(
                      icono: Icons.assignment_ind_outlined,
                      titulo: 'Crédito',
                      monto: resumen.vendidoCredito,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _TituloSeccion('Por sucursal'),
              const SizedBox(height: 8),
              if (visibles.isEmpty)
                const Text('Todavía no has creado ninguna sucursal.')
              else
                Card(
                  child: Column(
                    children: [
                      for (final s in visibles)
                        _FilaMonto(
                          icono: Icons.storefront_outlined,
                          titulo: s.nombre,
                          monto: resumen.porSucursal[s.id] ?? 0,
                        ),
                    ],
                  ),
                ),
            ],
          ),
          derecha: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TituloSeccion(porMes ? 'Ventas por mes' : 'Ventas por día'),
              const SizedBox(height: 8),
              _VentasPorFecha(
                rango: rango,
                porMes: porMes,
                porFecha: resumen.porFecha,
              ),
              const SizedBox(height: 24),
              const _TituloSeccion('Productos más vendidos'),
              const SizedBox(height: 8),
              _TopProductos(ranking: ranking),
            ],
          ),
        ),
      ],
    );
  }
}

class _VentasPorFecha extends StatelessWidget {
  final DateTimeRange rango;
  final bool porMes;
  final Map<DateTime, int> porFecha;

  const _VentasPorFecha({
    required this.rango,
    required this.porMes,
    required this.porFecha,
  });

  @override
  Widget build(BuildContext context) {
    // Se listan todas las fechas del rango, también las sin ventas, para que
    // los días en cero se vean como cero y no como un salto.
    final claves = <DateTime>[];
    var actual = porMes
        ? DateTime(rango.start.year, rango.start.month)
        : rango.start;
    while (!actual.isAfter(rango.end)) {
      claves.add(actual);
      actual = porMes
          ? DateTime(actual.year, actual.month + 1)
          : DateTime(actual.year, actual.month, actual.day + 1);
    }

    final maximo = porFecha.values.fold<int>(0, (a, b) => a > b ? a : b);
    String etiqueta(DateTime d) => porMes
        ? '${_nombresMeses[d.month - 1]} ${d.year}'
        : '${_nombresDias[d.weekday - 1]} '
              '${_dosDigitos(d.day)}/${_dosDigitos(d.month)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final clave in claves)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        etiqueta(clave),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: maximo == 0
                              ? 0
                              : (porFecha[clave] ?? 0) / maximo,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: Text(
                        formatearPesos(porFecha[clave] ?? 0),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

class _TopProductos extends StatelessWidget {
  final List<MapEntry<String, int>> ranking;

  const _TopProductos({required this.ranking});

  @override
  Widget build(BuildContext context) {
    final top = ranking.take(8).toList();

    if (top.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay ventas en este período'),
        ),
      );
    }

    return Card(
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
    );
  }
}

/// Turnos abiertos, alertas de stock bajo y deudas: lo que importa "ahora",
/// sin depender del rango de fechas elegido arriba.
class _PanelEstadoActual extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> turnosStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> productosStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> clientesStream;
  final List<Sucursal> sucursales;

  const _PanelEstadoActual({
    required this.turnosStream,
    required this.productosStream,
    required this.clientesStream,
    required this.sucursales,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: turnosStream,
      builder: (context, turnosSnap) {
        final turnosAbiertos = turnosSnap.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: productosStream,
          builder: (context, productosSnap) {
            final productos =
                productosSnap.data?.docs.map(Producto.fromDoc).toList() ?? [];

            // El stock es por sucursal, así que la alerta se arma revisando
            // cada combinación producto+sucursal por separado.
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
              stream: clientesStream,
              builder: (context, clientesSnap) {
                final conDeuda =
                    (clientesSnap.data?.docs.map(Cliente.fromDoc).toList() ??
                            [])
                        .where((c) => c.deuda > 0)
                        .toList()
                      ..sort((a, b) => b.deuda.compareTo(a.deuda));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
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
                    const SizedBox(height: 24),
                    _SeccionAlertas(stockBajo: stockBajo, conDeuda: conDeuda),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _DosColumnas extends StatelessWidget {
  final Widget izquierda;
  final Widget derecha;

  const _DosColumnas({required this.izquierda, required this.derecha});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [izquierda, const SizedBox(height: 32), derecha],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: izquierda),
            const SizedBox(width: 24),
            Expanded(child: derecha),
          ],
        );
      },
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;

  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}

class _FilaMonto extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final int monto;

  const _FilaMonto({
    required this.icono,
    required this.titulo,
    required this.monto,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icono),
      title: Text(titulo),
      trailing: Text(
        formatearPesos(monto),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Marca.doradoSuave,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icono, size: 26, color: Marca.cafe),
            ),
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

class _SeccionAlertas extends StatelessWidget {
  final List<_AlertaStock> stockBajo;
  final List<Cliente> conDeuda;

  const _SeccionAlertas({required this.stockBajo, required this.conDeuda});

  @override
  Widget build(BuildContext context) {
    final columnaStock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );

    final columnaDeuda = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

    return _DosColumnas(izquierda: columnaStock, derecha: columnaDeuda);
  }
}
