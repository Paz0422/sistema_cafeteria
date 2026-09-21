import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/utils/resumen_ventas.dart';

Map<String, dynamic> _venta({
  required int total,
  required String metodo,
  int? montoEfectivo,
  String sucursalId = 'centro',
  DateTime? fecha,
  bool cancelada = false,
  List<Map<String, dynamic>> items = const [],
}) => {
  'total': total,
  'metodoPago': metodo,
  // La app guarda lo que queda en caja: el total si fue efectivo, y 0 si
  // fue tarjeta o crédito.
  'montoEfectivo': montoEfectivo ?? (metodo == 'efectivo' ? total : 0),
  'sucursalId': sucursalId,
  'fecha': Timestamp.fromDate(fecha ?? DateTime(2026, 9, 14, 10, 30)),
  if (cancelada) 'cancelada': true,
  'items': items,
};

void main() {
  group('Totales y método de pago (cierre de turno y reportes)', () {
    test('sin ventas todo es 0 y el ticket promedio no divide por cero', () {
      final resumen = resumirVentas([]);
      expect(resumen.total, 0);
      expect(resumen.cantidadVentas, 0);
      expect(resumen.ticketPromedio, 0);
      expect(resumen.efectivoEnCaja, 0);
    });

    test('reparte el total entre efectivo, tarjeta y crédito', () {
      final resumen = resumirVentas([
        _venta(total: 5000, metodo: 'efectivo'),
        _venta(total: 3000, metodo: 'tarjeta'),
        _venta(total: 2000, metodo: 'credito'),
      ]);
      expect(resumen.total, 10000);
      expect(resumen.cantidadVentas, 3);
      expect(resumen.vendidoEfectivo, 5000);
      expect(resumen.vendidoTarjeta, 3000);
      expect(resumen.vendidoCredito, 2000);
      expect(
        resumen.vendidoEfectivo +
            resumen.vendidoTarjeta +
            resumen.vendidoCredito,
        resumen.total,
      );
    });

    test('una venta mixta se reparte entre efectivo y tarjeta', () {
      // Total $10.000: $2.000 quedaron en caja tras el vuelto, y el resto
      // ($8.000) fue con tarjeta.
      final resumen = resumirVentas([
        _venta(total: 10000, metodo: 'mixto', montoEfectivo: 2000),
      ]);
      expect(resumen.vendidoEfectivo, 2000);
      expect(resumen.vendidoTarjeta, 8000);
      expect(resumen.efectivoEnCaja, 2000);
      expect(resumen.total, 10000);
    });

    test('solo el efectivo suma al efectivo esperado en caja', () {
      final resumen = resumirVentas([
        _venta(total: 5000, metodo: 'efectivo'),
        _venta(total: 3000, metodo: 'tarjeta'),
        _venta(total: 2000, metodo: 'credito'),
        _venta(total: 10000, metodo: 'mixto', montoEfectivo: 2000),
      ]);
      const montoInicial = 50000;
      // 50.000 iniciales + 5.000 (efectivo) + 2.000 (parte efectivo del mixto)
      expect(montoInicial + resumen.efectivoEnCaja, 57000);
    });

    test('las ventas canceladas no cuentan en nada', () {
      final resumen = resumirVentas([
        _venta(total: 5000, metodo: 'efectivo'),
        _venta(total: 9000, metodo: 'efectivo', cancelada: true),
        _venta(
          total: 4000,
          metodo: 'tarjeta',
          cancelada: true,
          items: [
            {'nombre': 'Café', 'cantidad': 2},
          ],
        ),
      ]);
      expect(resumen.total, 5000);
      expect(resumen.cantidadVentas, 1);
      expect(resumen.vendidoTarjeta, 0);
      expect(resumen.efectivoEnCaja, 5000);
      expect(resumen.unidadesPorProducto, isEmpty);
    });

    test('el ticket promedio es la división entera del total', () {
      final resumen = resumirVentas([
        _venta(total: 1000, metodo: 'efectivo'),
        _venta(total: 1000, metodo: 'efectivo'),
        _venta(total: 1001, metodo: 'efectivo'),
      ]);
      expect(resumen.ticketPromedio, 1000);
    });

    test('un método de pago desconocido suma al total pero a ningún medio', () {
      final resumen = resumirVentas([_venta(total: 700, metodo: 'cheque')]);
      expect(resumen.total, 700);
      expect(resumen.vendidoEfectivo, 0);
      expect(resumen.vendidoTarjeta, 0);
      expect(resumen.vendidoCredito, 0);
    });
  });

  group('Filtro por sucursal', () {
    final ventas = [
      _venta(total: 1000, metodo: 'efectivo', sucursalId: 'centro'),
      _venta(total: 2000, metodo: 'tarjeta', sucursalId: 'kiosko'),
      _venta(total: 4000, metodo: 'efectivo', sucursalId: 'kiosko'),
    ];

    test('sin filtro suma todas y separa por sucursal', () {
      final resumen = resumirVentas(ventas);
      expect(resumen.total, 7000);
      expect(resumen.porSucursal, {'centro': 1000, 'kiosko': 6000});
    });

    test('con filtro solo cuenta la sucursal elegida', () {
      final resumen = resumirVentas(ventas, sucursalId: 'kiosko');
      expect(resumen.total, 6000);
      expect(resumen.cantidadVentas, 2);
      expect(resumen.vendidoTarjeta, 2000);
      expect(resumen.porSucursal.keys, ['kiosko']);
    });

    test('una sucursal sin ventas da 0', () {
      final resumen = resumirVentas(ventas, sucursalId: 'otra');
      expect(resumen.total, 0);
      expect(resumen.cantidadVentas, 0);
    });
  });

  group('Productos más vendidos', () {
    test('suma las unidades de un mismo producto entre ventas', () {
      final resumen = resumirVentas([
        _venta(
          total: 1,
          metodo: 'efectivo',
          items: [
            {'nombre': 'Café', 'cantidad': 2},
            {'nombre': 'Galleta', 'cantidad': 1},
          ],
        ),
        _venta(
          total: 1,
          metodo: 'efectivo',
          items: [
            {'nombre': 'Café', 'cantidad': 3},
          ],
        ),
      ]);
      expect(resumen.unidadesPorProducto, {'Café': 5, 'Galleta': 1});
    });
  });

  group('Ventas por día y por mes', () {
    final ventas = [
      _venta(
        total: 1000,
        metodo: 'efectivo',
        fecha: DateTime(2026, 9, 14, 8, 0),
      ),
      _venta(
        total: 2000,
        metodo: 'efectivo',
        fecha: DateTime(2026, 9, 14, 23, 59),
      ),
      _venta(
        total: 4000,
        metodo: 'efectivo',
        fecha: DateTime(2026, 9, 15, 0, 0),
      ),
      _venta(
        total: 8000,
        metodo: 'efectivo',
        fecha: DateTime(2026, 10, 1, 12, 0),
      ),
    ];

    test('agrupa por día: 23:59 y 00:00 caen en días distintos', () {
      final resumen = resumirVentas(ventas);
      expect(resumen.porFecha, {
        DateTime(2026, 9, 14): 3000,
        DateTime(2026, 9, 15): 4000,
        DateTime(2026, 10, 1): 8000,
      });
    });

    test('agrupa por mes con la clave en el primer día del mes', () {
      final resumen = resumirVentas(ventas, porMes: true);
      expect(resumen.porFecha, {
        DateTime(2026, 9): 7000,
        DateTime(2026, 10): 8000,
      });
    });
  });

  group('Rango de fechas de cada período', () {
    // Jueves 17 de septiembre de 2026.
    final ahora = DateTime(2026, 9, 17, 15, 45);

    test('hoy es solo el día actual', () {
      final rango = rangoDe(PeriodoReporte.hoy, ahora: ahora);
      expect(rango.start, DateTime(2026, 9, 17));
      expect(rango.end, DateTime(2026, 9, 17));
      expect(diasDelRango(rango), 1);
    });

    test('ayer es solo el día anterior', () {
      final rango = rangoDe(PeriodoReporte.ayer, ahora: ahora);
      expect(rango.start, DateTime(2026, 9, 16));
      expect(rango.end, DateTime(2026, 9, 16));
    });

    test('últimos 7 días incluye hoy y son exactamente 7 días', () {
      final rango = rangoDe(PeriodoReporte.sieteDias, ahora: ahora);
      expect(rango.start, DateTime(2026, 9, 11));
      expect(rango.end, DateTime(2026, 9, 17));
      expect(diasDelRango(rango), 7);
    });

    test('este mes va del día 1 hasta hoy', () {
      final rango = rangoDe(PeriodoReporte.mes, ahora: ahora);
      expect(rango.start, DateTime(2026, 9));
      expect(rango.end, DateTime(2026, 9, 17));
      expect(diasDelRango(rango), 17);
    });

    test('el día 1 del mes, "este mes" es un solo día', () {
      final rango = rangoDe(PeriodoReporte.mes, ahora: DateTime(2026, 10, 1));
      expect(rango.start, DateTime(2026, 10));
      expect(rango.end, DateTime(2026, 10));
    });

    test('ayer cruza el cambio de mes', () {
      final rango = rangoDe(PeriodoReporte.ayer, ahora: DateTime(2026, 3, 1));
      expect(rango.start, DateTime(2026, 2, 28));
    });

    test('últimos 7 días cruza el cambio de mes', () {
      final rango = rangoDe(
        PeriodoReporte.sieteDias,
        ahora: DateTime(2026, 3, 3),
      );
      expect(rango.start, DateTime(2026, 2, 25));
      expect(diasDelRango(rango), 7);
    });

    test('ayer cruza el cambio de año', () {
      final rango = rangoDe(PeriodoReporte.ayer, ahora: DateTime(2027, 1, 1));
      expect(rango.start, DateTime(2026, 12, 31));
    });

    test('la hora del día no altera el rango', () {
      final madrugada = rangoDe(
        PeriodoReporte.hoy,
        ahora: DateTime(2026, 9, 17, 0, 0, 1),
      );
      final noche = rangoDe(
        PeriodoReporte.hoy,
        ahora: DateTime(2026, 9, 17, 23, 59, 59),
      );
      expect(madrugada, noche);
    });
  });

  group('Cuándo se agrupa por mes', () {
    DateTimeRange rango(DateTime a, DateTime b) =>
        DateTimeRange(start: a, end: b);

    test('62 días todavía se ven por día; 63 pasan a mes', () {
      final inicio = DateTime(2026, 1, 1);
      expect(agruparPorMes(rango(inicio, DateTime(2026, 3, 3))), isFalse);
      expect(agruparPorMes(rango(inicio, DateTime(2026, 3, 4))), isTrue);
    });

    test('el conteo de días no se descuadra por un cambio de hora', () {
      // Chile cambia la hora el primer sábado de septiembre y de abril; entre
      // dos medianoches locales que lo cruzan hay 23 o 25 horas.
      final rango = DateTimeRange(
        start: DateTime(2026, 8, 25),
        end: DateTime(2026, 10, 25),
      );
      expect(diasDelRango(rango), 62);
    });
  });
}
