import 'package:flutter/material.dart';

import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/sucursal.dart';
import '../theme/marca.dart';
import '../utils/formato.dart';
import '../utils/resumen_ventas.dart';
import '../widgets/graficos.dart';
import '../widgets/premium.dart';

/// Bajo este ancho (celulares) se compactan márgenes y tarjetas.
const anchoCompacto = 600.0;

bool esCompacto(BuildContext context) =>
    MediaQuery.sizeOf(context).width < anchoCompacto;

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

const _colorEfectivo = Marca.dorado;
const _colorTarjeta = Marca.texto;
const _colorCredito = Marca.cafe;

/// Producto con poco stock en una sucursal.
class AlertaStock {
  final Producto producto;
  final String sucursalNombre;
  final int stock;

  const AlertaStock({
    required this.producto,
    required this.sucursalNombre,
    required this.stock,
  });
}

/// Dos columnas en pantallas anchas, una sola en celular.
class DosColumnas extends StatelessWidget {
  final Widget izquierda;
  final Widget derecha;

  const DosColumnas({
    super.key,
    required this.izquierda,
    required this.derecha,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [izquierda, const SizedBox(height: 28), derecha],
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

/// Todo lo que depende del período elegido: total, métodos de pago, ventas
/// por sucursal, evolución en el tiempo y productos más vendidos.
class VistaResumen extends StatelessWidget {
  final ResumenVentas resumen;
  final List<Sucursal> sucursales;
  final String? sucursalFiltrada;
  final DateTimeRange rango;

  const VistaResumen({
    super.key,
    required this.resumen,
    required this.sucursales,
    required this.sucursalFiltrada,
    required this.rango,
  });

  @override
  Widget build(BuildContext context) {
    final porMes = agruparPorMes(rango);
    final visibles = sucursalFiltrada == null
        ? sucursales
        : sucursales.where((s) => s.id == sucursalFiltrada).toList();
    final ranking = resumen.unidadesPorProducto.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Aparecer(child: _Cabecera(resumen: resumen)),
        const SizedBox(height: 28),
        DosColumnas(
          izquierda: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Aparecer(indice: 1, child: _MetodosDePago(resumen: resumen)),
              const SizedBox(height: 28),
              Aparecer(
                indice: 2,
                child: _PorSucursal(resumen: resumen, sucursales: visibles),
              ),
            ],
          ),
          derecha: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Aparecer(
                indice: 1,
                child: _VentasPorFecha(
                  // Si cambia el período se reinicia la barra elegida.
                  key: ValueKey('${rango.start}-${rango.end}'),
                  rango: rango,
                  porMes: porMes,
                  porFecha: resumen.porFecha,
                ),
              ),
              const SizedBox(height: 28),
              Aparecer(indice: 2, child: _TopProductos(ranking: ranking)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  final ResumenVentas resumen;

  const _Cabecera({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final compacto = esCompacto(context);

    final total = TarjetaFusion(
      brillo: true,
      padding: EdgeInsets.all(compacto ? 18 : 22),
      child: Row(
        children: [
          IconoDorado(Icons.trending_up_rounded, tamano: compacto ? 24 : 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total vendido',
                  style: TextStyle(color: Marca.textoSuave, fontSize: 13),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: NumeroAnimado(
                    valor: resumen.total,
                    formato: formatearPesos,
                    estilo: TextStyle(
                      fontSize: compacto ? 32 : 38,
                      fontWeight: FontWeight.w800,
                      color: Marca.texto,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final ventas = _Kpi(
      icono: Icons.receipt_long_rounded,
      titulo: 'Ventas',
      child: NumeroAnimado(
        valor: resumen.cantidadVentas,
        formato: (v) => '$v',
        estilo: _estiloKpi,
      ),
    );
    final ticket = _Kpi(
      icono: Icons.confirmation_number_outlined,
      titulo: 'Ticket promedio',
      child: NumeroAnimado(
        valor: resumen.ticketPromedio,
        formato: formatearPesos,
        estilo: _estiloKpi,
      ),
    );

    if (compacto) {
      return Column(
        children: [
          total,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ventas),
              const SizedBox(width: 12),
              Expanded(child: ticket),
            ],
          ),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: total),
          const SizedBox(width: 16),
          Expanded(child: ventas),
          const SizedBox(width: 16),
          Expanded(child: ticket),
        ],
      ),
    );
  }
}

const _estiloKpi = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: Marca.texto,
);

class _Kpi extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Widget child;

  const _Kpi({required this.icono, required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return TarjetaFusion(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 20, color: Marca.dorado),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: const TextStyle(color: Marca.textoSuave, fontSize: 12),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _MetodosDePago extends StatelessWidget {
  final ResumenVentas resumen;

  const _MetodosDePago({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final tramos = [
      TramoDona('Efectivo', resumen.vendidoEfectivo, _colorEfectivo),
      TramoDona('Tarjeta', resumen.vendidoTarjeta, _colorTarjeta),
      TramoDona('Crédito', resumen.vendidoCredito, _colorCredito),
    ];
    final suma = tramos.fold<int>(0, (a, t) => a + t.valor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TituloSeccion('Por método de pago'),
        const SizedBox(height: 12),
        TarjetaFusion(
          child: Row(
            children: [
              DonaFusion(
                tramos: tramos,
                tamano: 132,
                centro: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${resumen.cantidadVentas}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Marca.texto,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'ventas',
                      style: TextStyle(color: Marca.textoSuave, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    for (final t in tramos)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: t.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t.nombre,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatearPesos(t.valor),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  suma == 0
                                      ? '0%'
                                      : '${(t.valor * 100 / suma).round()}%',
                                  style: const TextStyle(
                                    color: Marca.textoSuave,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PorSucursal extends StatelessWidget {
  final ResumenVentas resumen;
  final List<Sucursal> sucursales;

  const _PorSucursal({required this.resumen, required this.sucursales});

  @override
  Widget build(BuildContext context) {
    final maximo = sucursales.fold<int>(
      0,
      (a, s) => a > (resumen.porSucursal[s.id] ?? 0)
          ? a
          : (resumen.porSucursal[s.id] ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TituloSeccion('Por sucursal'),
        const SizedBox(height: 12),
        if (sucursales.isEmpty)
          const Text('Todavía no has creado ninguna sucursal.')
        else
          TarjetaFusion(
            child: Column(
              children: [
                for (final s in sucursales)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 18,
                              color: Marca.dorado,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.nombre,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              formatearPesos(resumen.porSucursal[s.id] ?? 0),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        BarraFusion(
                          proporcion: maximo == 0
                              ? 0
                              : (resumen.porSucursal[s.id] ?? 0) / maximo,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VentasPorFecha extends StatefulWidget {
  final DateTimeRange rango;
  final bool porMes;
  final Map<DateTime, int> porFecha;

  const _VentasPorFecha({
    super.key,
    required this.rango,
    required this.porMes,
    required this.porFecha,
  });

  @override
  State<_VentasPorFecha> createState() => _VentasPorFechaState();
}

class _VentasPorFechaState extends State<_VentasPorFecha> {
  int? _elegida;

  List<DateTime> get _claves {
    // Se incluyen también las fechas sin ventas, para que un día en cero se
    // vea como cero y no como un salto.
    final claves = <DateTime>[];
    var actual = widget.porMes
        ? DateTime(widget.rango.start.year, widget.rango.start.month)
        : widget.rango.start;
    while (!actual.isAfter(widget.rango.end)) {
      claves.add(actual);
      actual = widget.porMes
          ? DateTime(actual.year, actual.month + 1)
          : DateTime(actual.year, actual.month, actual.day + 1);
    }
    return claves;
  }

  @override
  Widget build(BuildContext context) {
    final claves = _claves;
    final puntos = [
      for (final d in claves)
        PuntoBarra(
          widget.porMes
              ? _nombresMeses[d.month - 1]
              : claves.length <= 7
              ? _nombresDias[d.weekday - 1]
              : _dosDigitos(d.day),
          widget.porMes
              ? '${_nombresMeses[d.month - 1]} ${d.year}'
              : '${_nombresDias[d.weekday - 1]} '
                    '${_dosDigitos(d.day)}/${_dosDigitos(d.month)}',
          widget.porFecha[d] ?? 0,
        ),
    ];
    final elegida = _elegida ?? (puntos.isEmpty ? null : puntos.length - 1);
    final punto = elegida == null ? null : puntos[elegida];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TituloSeccion(widget.porMes ? 'Ventas por mes' : 'Ventas por día'),
        const SizedBox(height: 12),
        TarjetaFusion(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    punto?.detalle ?? '',
                    style: const TextStyle(
                      color: Marca.textoSuave,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatearPesos(punto?.valor ?? 0),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Marca.dorado,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GraficoBarrasFusion(
                puntos: puntos,
                seleccionado: elegida,
                alSeleccionar: (i) => setState(() => _elegida = i),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopProductos extends StatelessWidget {
  final List<MapEntry<String, int>> ranking;

  const _TopProductos({required this.ranking});

  @override
  Widget build(BuildContext context) {
    final top = ranking.take(8).toList();
    final maximo = top.isEmpty ? 0 : top.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TituloSeccion('Productos más vendidos'),
        const SizedBox(height: 12),
        if (top.isEmpty)
          const TarjetaFusion(child: Text('No hay ventas en este período'))
        else
          TarjetaFusion(
            child: Column(
              children: [
                for (var i = 0; i < top.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        _Posicion(i + 1),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      top[i].key,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${top[i].value} und.',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              BarraFusion(
                                proporcion: top[i].value / maximo,
                                alto: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Posicion extends StatelessWidget {
  final int numero;

  const _Posicion(this.numero);

  @override
  Widget build(BuildContext context) {
    final podio = numero <= 3;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: podio ? Marca.degradadoDorado : null,
        color: podio ? null : Marca.carbonClaro,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$numero',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: podio ? Marca.negro : Marca.textoSuave,
        ),
      ),
    );
  }
}

/// Lo que importa "ahora", sin depender del rango elegido: turnos abiertos,
/// alertas de stock y deudas.
class VistaEstadoActual extends StatelessWidget {
  final int turnosAbiertos;
  final int cantidadSucursales;
  final List<AlertaStock> stockBajo;
  final List<Cliente> conDeuda;
  final int umbralStockBajo;

  const VistaEstadoActual({
    super.key,
    required this.turnosAbiertos,
    required this.cantidadSucursales,
    required this.stockBajo,
    required this.conDeuda,
    required this.umbralStockBajo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Kpi(
                icono: Icons.point_of_sale_rounded,
                titulo: 'Turnos abiertos',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NumeroAnimado(
                      valor: turnosAbiertos,
                      formato: (v) => '$v',
                      estilo: _estiloKpi,
                    ),
                    if (turnosAbiertos > 0) ...[
                      const SizedBox(width: 8),
                      const PuntoVivo(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Kpi(
                icono: Icons.storefront_rounded,
                titulo: 'Sucursales',
                child: NumeroAnimado(
                  valor: cantidadSucursales,
                  formato: (v) => '$v',
                  estilo: _estiloKpi,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DosColumnas(
          izquierda: _Alertas(
            titulo: 'Stock bajo (≤ $umbralStockBajo unidades)',
            vacio: 'Ningún producto con stock bajo',
            filas: [
              for (final a in stockBajo)
                _FilaAlerta(
                  icono: Icons.warning_amber_rounded,
                  color: a.stock == 0 ? Marca.peligro : Marca.alerta,
                  titulo: a.producto.nombre,
                  subtitulo: a.sucursalNombre,
                  valor: 'Stock: ${a.stock}',
                ),
            ],
          ),
          derecha: _Alertas(
            titulo: 'Clientes con deuda',
            vacio: 'Ningún cliente tiene deuda pendiente',
            filas: [
              for (final c in conDeuda.take(8))
                _FilaAlerta(
                  icono: Icons.person_rounded,
                  color: c.deuda >= c.limiteCredito
                      ? Marca.peligro
                      : Marca.alerta,
                  titulo: c.nombre,
                  subtitulo: c.telefono.isEmpty ? null : c.telefono,
                  valor:
                      '${formatearPesos(c.deuda)} de '
                      '${formatearPesos(c.limiteCredito)}',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaAlerta {
  final IconData icono;
  final Color color;
  final String titulo;
  final String? subtitulo;
  final String valor;

  const _FilaAlerta({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.valor,
    this.subtitulo,
  });
}

class _Alertas extends StatelessWidget {
  final String titulo;
  final String vacio;
  final List<_FilaAlerta> filas;

  const _Alertas({
    required this.titulo,
    required this.vacio,
    required this.filas,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Marca.textoSobreOscuro,
          ),
        ),
        const SizedBox(height: 8),
        if (filas.isEmpty)
          TarjetaFusion(
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Marca.exito,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(vacio)),
              ],
            ),
          )
        else
          TarjetaFusion(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < filas.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: filas[i].color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            filas[i].icono,
                            size: 18,
                            color: filas[i].color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filas[i].titulo,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (filas[i].subtitulo != null)
                                Text(
                                  filas[i].subtitulo!,
                                  style: const TextStyle(
                                    color: Marca.textoSuave,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            filas[i].valor,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: filas[i].color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
