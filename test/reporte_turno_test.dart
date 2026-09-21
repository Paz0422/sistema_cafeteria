import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/utils/reporte_turno.dart';

Map<String, dynamic> _venta({
  required String metodo,
  required int total,
  int montoEfectivo = 0,
  required List<Map<String, dynamic>> items,
  bool cancelada = false,
  String? cliente,
  DateTime? fecha,
}) => {
  'metodoPago': metodo,
  'total': total,
  'montoEfectivo': montoEfectivo,
  'items': items,
  'cancelada': cancelada,
  'clienteNombre': cliente,
  'fecha': Timestamp.fromDate(fecha ?? DateTime(2026, 9, 21, 10, 0)),
};

Map<String, dynamic> _item(String nombre, int cantidad, int subtotal) => {
  'nombre': nombre,
  'cantidad': cantidad,
  'subtotal': subtotal,
};

DatosReporteTurno _datos({int billetes = 0, int monedas = 0}) =>
    armarDatosReporteTurno(
      sucursal: 'CDA',
      vendedor: 'Julio Vallejos',
      apertura: DateTime(2026, 9, 21, 8, 0),
      cierre: DateTime(2026, 9, 21, 16, 30),
      montoInicial: 20000,
      billetesContados: billetes,
      monedasContadas: monedas,
      ventas: [
        _venta(
          metodo: 'efectivo',
          total: 5000,
          montoEfectivo: 5000,
          items: [_item('Café latte', 2, 3000), _item('Brownie', 1, 2000)],
          fecha: DateTime(2026, 9, 21, 9, 30),
        ),
        _venta(
          metodo: 'tarjeta',
          total: 3000,
          items: [_item('Café latte', 2, 3000)],
          fecha: DateTime(2026, 9, 21, 9, 0),
        ),
        _venta(
          metodo: 'credito',
          total: 2000,
          cliente: 'María González',
          items: [_item('Brownie', 1, 2000)],
        ),
        // Anulada: se lista pero no suma en nada.
        _venta(
          metodo: 'efectivo',
          total: 9000,
          montoEfectivo: 9000,
          cancelada: true,
          items: [_item('Jugo', 3, 9000)],
        ),
      ],
    );

void main() {
  group('armarDatosReporteTurno', () {
    test('las ventas anuladas no suman en totales ni en productos', () {
      final d = _datos();
      expect(d.resumen.total, 10000);
      expect(d.resumen.cantidadVentas, 3);
      expect(d.anuladas, 1);
      expect(d.productos.map((p) => p.nombre), isNot(contains('Jugo')));
    });

    test('los productos suman unidades y monto, del más vendido al menos', () {
      final productos = _datos().productos;
      expect(productos.map((p) => p.nombre), ['Café latte', 'Brownie']);
      expect(productos[0].unidades, 4);
      expect(productos[0].monto, 6000);
      expect(productos[1].unidades, 2);
      expect(productos[1].monto, 4000);
    });

    test('el detalle va ordenado por hora e incluye las anuladas', () {
      final ventas = _datos().ventas;
      expect(ventas.length, 4);
      final horas = ventas.map((v) => v.hora).toList();
      expect([...horas]..sort(), horas);
      expect(ventas.where((v) => v.anulada).length, 1);
    });

    test('la cuadratura usa el efectivo que realmente entró', () {
      final d = _datos(billetes: 24000, monedas: 1000);
      expect(d.efectivoEsperado, 25000); // 20.000 iniciales + 5.000
      expect(d.totalContado, 25000);
      expect(d.diferencia, 0);
      expect(_datos(billetes: 20000).diferencia, -5000);
      expect(_datos(billetes: 30000).diferencia, 5000);
    });
  });

  test('generarPdfReporteTurno produce un PDF con contenido', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await generarPdfReporteTurno(
      _datos(billetes: 24000, monedas: 1000),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(2000));

    // Se deja una copia para revisarla a ojo.
    final salida = Platform.environment['REPORTE_TURNO_SALIDA'];
    if (salida != null) File(salida).writeAsBytesSync(bytes);
  });
}
