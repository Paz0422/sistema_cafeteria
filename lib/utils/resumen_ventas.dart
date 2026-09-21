import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart' show DateTimeRange;

/// Sobre este largo de rango las ventas se agrupan por mes en vez de por día,
/// para que el desglose no pase de unas 60 filas.
const maxDiasAgrupadoPorDia = 62;

enum PeriodoReporte {
  hoy('Hoy'),
  ayer('Ayer'),
  sieteDias('Últimos 7 días'),
  mes('Este mes'),
  personalizado('Personalizado');

  final String etiqueta;
  const PeriodoReporte(this.etiqueta);
}

DateTime soloDia(DateTime fecha) =>
    DateTime(fecha.year, fecha.month, fecha.day);

/// Rango de días completos: de `start` a `end`, ambos incluidos. [ahora] se
/// puede fijar para probarlo.
DateTimeRange rangoDe(PeriodoReporte periodo, {DateTime? ahora}) {
  final hoy = soloDia(ahora ?? DateTime.now());
  switch (periodo) {
    case PeriodoReporte.hoy:
    case PeriodoReporte.personalizado:
      return DateTimeRange(start: hoy, end: hoy);
    case PeriodoReporte.ayer:
      final ayer = DateTime(hoy.year, hoy.month, hoy.day - 1);
      return DateTimeRange(start: ayer, end: ayer);
    case PeriodoReporte.sieteDias:
      return DateTimeRange(
        start: DateTime(hoy.year, hoy.month, hoy.day - 6),
        end: hoy,
      );
    case PeriodoReporte.mes:
      return DateTimeRange(start: DateTime(hoy.year, hoy.month), end: hoy);
  }
}

/// Cantidad de días que abarca el rango, contando ambos extremos. Se calcula
/// en UTC: entre dos medianoches locales que cruzan un cambio de hora hay 23 o
/// 25 horas, y `inDays` se comería un día.
int diasDelRango(DateTimeRange rango) =>
    DateTime.utc(rango.end.year, rango.end.month, rango.end.day)
        .difference(
          DateTime.utc(rango.start.year, rango.start.month, rango.start.day),
        )
        .inDays +
    1;

bool agruparPorMes(DateTimeRange rango) =>
    diasDelRango(rango) > maxDiasAgrupadoPorDia;

/// Totales de un conjunto de ventas. Lo usan el cierre de turno y los
/// reportes, así que ambos cuadran con las mismas reglas:
/// - las ventas canceladas no cuentan;
/// - una venta mixta se reparte: su parte en efectivo suma a efectivo y el
///   resto (lo que no fue efectivo) a tarjeta.
class ResumenVentas {
  int total = 0;
  int cantidadVentas = 0;

  /// Dinero que realmente entró a la caja en efectivo (ya descontado el
  /// vuelto). Es lo que se suma al monto inicial para el "efectivo esperado".
  int efectivoEnCaja = 0;

  /// Cuánto de lo vendido se pagó en efectivo / tarjeta / crédito.
  int vendidoEfectivo = 0;
  int vendidoTarjeta = 0;
  int vendidoCredito = 0;

  final Map<String, int> porSucursal = {};
  final Map<String, int> unidadesPorProducto = {};
  final Map<DateTime, int> porFecha = {};

  int get ticketPromedio => cantidadVentas == 0 ? 0 : total ~/ cantidadVentas;
}

/// Suma [ventas] (los datos de cada documento de `ventas`).
///
/// Con [sucursalId] solo se cuentan las de esa sucursal. [porMes] agrupa
/// `porFecha` por mes (clave: primer día del mes) en vez de por día.
ResumenVentas resumirVentas(
  Iterable<Map<String, dynamic>> ventas, {
  String? sucursalId,
  bool porMes = false,
}) {
  DateTime claveDe(DateTime fecha) =>
      porMes ? DateTime(fecha.year, fecha.month) : soloDia(fecha);

  final resumen = ResumenVentas();
  for (final datos in ventas) {
    if (datos['cancelada'] == true) continue;

    final idSucursal = datos['sucursalId'] as String? ?? '';
    if (sucursalId != null && idSucursal != sucursalId) continue;

    final total = (datos['total'] as num?)?.toInt() ?? 0;
    final montoEfectivo = (datos['montoEfectivo'] as num?)?.toInt() ?? 0;
    final fecha = (datos['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();

    resumen.total += total;
    // Un cambio de producto ajusta los montos pero no es una venta más: no
    // cuenta en la cantidad de ventas ni en el ticket promedio.
    if (datos['esCambio'] != true) resumen.cantidadVentas++;
    resumen.efectivoEnCaja += montoEfectivo;
    resumen.porSucursal[idSucursal] =
        (resumen.porSucursal[idSucursal] ?? 0) + total;
    final clave = claveDe(fecha);
    resumen.porFecha[clave] = (resumen.porFecha[clave] ?? 0) + total;

    switch (datos['metodoPago']) {
      case 'efectivo':
        resumen.vendidoEfectivo += total;
      case 'tarjeta':
        resumen.vendidoTarjeta += total;
      case 'mixto':
        resumen.vendidoEfectivo += montoEfectivo;
        resumen.vendidoTarjeta += total - montoEfectivo;
      case 'credito':
        resumen.vendidoCredito += total;
    }

    for (final item in (datos['items'] as List? ?? [])) {
      final nombre = item['nombre'] as String? ?? '';
      final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;
      resumen.unidadesPorProducto[nombre] =
          (resumen.unidadesPorProducto[nombre] ?? 0) + cantidad;
    }
  }
  return resumen;
}
