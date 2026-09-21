import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/sucursal.dart';
import '../theme/marca.dart';
import '../utils/resumen_ventas.dart';
import '../widgets/premium.dart';
import 'estadisticas_vistas.dart';

const _umbralStockBajo = 5;

String _dosDigitos(int n) => n.toString().padLeft(2, '0');

String _formatearDia(DateTime d) =>
    '${_dosDigitos(d.day)}/${_dosDigitos(d.month)}/${d.year}';

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
      body: FondoFusion(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: ListView(
                      padding: EdgeInsets.all(esCompacto(context) ? 16 : 24),
                      children: [
                        _BarraFiltros(
                          periodo: _periodo,
                          etiquetaRango: _etiquetaRango,
                          onPeriodo: _elegirPeriodo,
                          onPersonalizado: _elegirRangoPersonalizado,
                          sucursales: sucursales,
                          sucursalId: filtro,
                          onSucursal: (id) =>
                              setState(() => _sucursalFiltro = id),
                        ),
                        const SizedBox(height: 24),
                        if (ventasSnap.hasError)
                          Text(
                            'No se pudieron cargar las ventas: '
                            '${ventasSnap.error}',
                          )
                        else if (!ventasSnap.hasData)
                          const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          VistaResumen(
                            resumen: _resumir(ventasSnap.data!.docs, filtro),
                            sucursales: sucursales,
                            sucursalFiltrada: filtro,
                            rango: _rango,
                          ),
                        const SizedBox(height: 36),
                        const TituloSeccion('Estado actual'),
                        const SizedBox(height: 12),
                        _EstadoActual(
                          turnosStream: _turnosAbiertosStream,
                          productosStream: _productosStream,
                          clientesStream: _clientesStream,
                          sucursales: sucursales,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
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
    final compacto = esCompacto(context);

    final chips = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in PeriodoReporte.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(p.etiqueta),
              avatar: p == PeriodoReporte.personalizado
                  ? Icon(
                      Icons.date_range,
                      size: 18,
                      color: p == periodo ? Marca.negro : Marca.dorado,
                    )
                  : null,
              selected: p == periodo,
              showCheckmark: false,
              onSelected: (_) => p == PeriodoReporte.personalizado
                  ? onPersonalizado()
                  : onPeriodo(p),
            ),
          ),
      ],
    );

    final selectorSucursal = SizedBox(
      width: compacto ? double.infinity : 280,
      child: DropdownButtonFormField<String?>(
        isExpanded: true,
        initialValue: sucursalId,
        decoration: const InputDecoration(
          labelText: 'Sucursal',
          prefixIcon: Icon(Icons.storefront_outlined),
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
    );

    final rango = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen',
          style: TextStyle(color: Marca.textoSuave, fontSize: 13),
        ),
        Text(
          etiquetaRango,
          style: TextStyle(
            fontSize: compacto ? 22 : 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compacto) ...[
          rango,
          const SizedBox(height: 14),
          selectorSucursal,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: rango),
              selectorSucursal,
            ],
          ),
        const SizedBox(height: 14),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: chips),
      ],
    );
  }
}

/// Escucha turnos, productos y clientes y arma [VistaEstadoActual].
class _EstadoActual extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> turnosStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> productosStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> clientesStream;
  final List<Sucursal> sucursales;

  const _EstadoActual({
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
            final stockBajo = <AlertaStock>[];
            for (final producto in productos) {
              if (!producto.controlaStock) continue;
              for (final sucursal in sucursales) {
                final stock = producto.stockEn(sucursal.id);
                if (stock <= _umbralStockBajo) {
                  stockBajo.add(
                    AlertaStock(
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

                return VistaEstadoActual(
                  turnosAbiertos: turnosAbiertos,
                  cantidadSucursales: sucursales.length,
                  stockBajo: stockBajo,
                  conDeuda: conDeuda,
                  umbralStockBajo: _umbralStockBajo,
                );
              },
            );
          },
        );
      },
    );
  }
}
