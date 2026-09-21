import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/models/producto.dart';
import 'package:cafeteria_sistema/utils/cambio_venta.dart';
import 'package:cafeteria_sistema/utils/resumen_ventas.dart';

const _mocha = Producto(
  id: 'mocha',
  codigoBarras: '2',
  nombre: 'Café mocha',
  precio: 2500,
);
const _barra = Producto(
  id: 'barra',
  codigoBarras: '3',
  nombre: 'Barra de cereal',
  precio: 800,
);
const _galleta = Producto(
  id: 'galleta',
  codigoBarras: '4',
  nombre: 'Galleta',
  precio: 1000,
  promoCantidad: 3,
  promoPrecioPack: 2400,
);

ItemVenta _item(
  String id,
  String nombre,
  int cantidad,
  int precio, [
  int? subtotal,
]) => ItemVenta(
  productoId: id,
  nombre: nombre,
  cantidad: cantidad,
  precioUnitario: precio,
  subtotal: subtotal ?? cantidad * precio,
);

void main() {
  group('valorDeDevolucion', () {
    test('devolver todo vale lo que se pagó', () {
      expect(valorDeDevolucion(_item('a', 'A', 3, 1000, 2400), 3), 2400);
    });

    test('sin promo, cada unidad vale su precio', () {
      expect(valorDeDevolucion(_item('a', 'A', 3, 1000), 2), 2000);
    });

    test('con promo se reparte lo pagado entre las unidades', () {
      // 3 galletas pagadas 2.400 (promo): devolver 1 son 800.
      expect(valorDeDevolucion(_item('g', 'Galleta', 3, 1000, 2400), 1), 800);
    });
  });

  group('CalculoCambio: la diferencia', () {
    final itemLatte = _item('latte', 'Café latte', 1, 2000);

    test('mismo precio (cambio de sabor): no hay nada que cobrar', () {
      const otroSabor = Producto(
        id: 'moka',
        codigoBarras: '9',
        nombre: 'Latte vainilla',
        precio: 2000,
      );
      final c = CalculoCambio(
        itemDevuelto: itemLatte,
        unidades: 1,
        productoNuevo: otroSabor,
      );
      expect(c.diferencia, 0);
    });

    test('a un producto más caro, el cliente paga la diferencia', () {
      final c = CalculoCambio(
        itemDevuelto: itemLatte,
        unidades: 1,
        productoNuevo: _mocha,
      );
      expect(c.diferencia, 500);
    });

    test('a uno más barato, se le devuelve la diferencia (negativa)', () {
      final c = CalculoCambio(
        itemDevuelto: itemLatte,
        unidades: 1,
        productoNuevo: _barra,
      );
      expect(c.diferencia, -1200);
    });

    test('con varias unidades usa la promo del producto nuevo', () {
      // Devuelve 3 lattes (6.000) y se lleva 3 galletas en promo (2.400).
      final c = CalculoCambio(
        itemDevuelto: _item('latte', 'Café latte', 3, 2000),
        unidades: 3,
        productoNuevo: _galleta,
      );
      expect(c.valorNuevo, 2400);
      expect(c.diferencia, 2400 - 6000);
    });

    test(
      'los items del cambio: el que vuelve en negativo, el nuevo positivo',
      () {
        final c = CalculoCambio(
          itemDevuelto: itemLatte,
          unidades: 1,
          productoNuevo: _mocha,
        );
        expect(c.items[0]['productoId'], 'latte');
        expect(c.items[0]['cantidad'], -1);
        expect(c.items[0]['subtotal'], -2000);
        expect(c.items[1]['productoId'], 'mocha');
        expect(c.items[1]['cantidad'], 1);
        expect(c.items[1]['subtotal'], 2500);
      },
    );
  });

  group('itemsNetos: lo que tiene hoy la venta', () {
    final original = [
      _item('latte', 'Café latte', 2, 2000).aMapa(),
      _item('barra', 'Barra de cereal', 1, 800).aMapa(),
    ];

    test('sin cambios son los originales', () {
      final netos = itemsNetos(original, const []);
      expect(netos.map((i) => i.productoId), ['latte', 'barra']);
    });

    test('un cambio reemplaza una unidad por otro producto', () {
      final cambio = CalculoCambio(
        itemDevuelto: _item('latte', 'Café latte', 2, 2000),
        unidades: 1,
        productoNuevo: _mocha,
      ).items;
      final netos = itemsNetos(original, [cambio]);
      final porId = {for (final i in netos) i.productoId: i.cantidad};
      expect(porId, {'latte': 1, 'barra': 1, 'mocha': 1});
    });

    test('lo que se devuelve completo desaparece de la lista', () {
      final cambio = CalculoCambio(
        itemDevuelto: _item('barra', 'Barra de cereal', 1, 800),
        unidades: 1,
        productoNuevo: _mocha,
      ).items;
      final netos = itemsNetos(original, [cambio]);
      expect(netos.map((i) => i.productoId), isNot(contains('barra')));
    });
  });

  group('mediosPermitidos', () {
    test('sin diferencia no hay nada que pagar', () {
      expect(
        mediosPermitidos(metodoOriginal: 'efectivo', diferencia: 0),
        isEmpty,
      );
    });

    test('una venta a crédito solo mueve la deuda', () {
      expect(mediosPermitidos(metodoOriginal: 'credito', diferencia: 500), [
        MedioDiferencia.deuda,
      ]);
      expect(mediosPermitidos(metodoOriginal: 'credito', diferencia: -500), [
        MedioDiferencia.deuda,
      ]);
    });

    test('cobrar se puede en efectivo o tarjeta', () {
      expect(mediosPermitidos(metodoOriginal: 'efectivo', diferencia: 500), [
        MedioDiferencia.efectivo,
        MedioDiferencia.tarjeta,
      ]);
    });

    test('devolver a la tarjeta solo si la venta se pagó con tarjeta', () {
      expect(mediosPermitidos(metodoOriginal: 'efectivo', diferencia: -500), [
        MedioDiferencia.efectivo,
      ]);
      expect(mediosPermitidos(metodoOriginal: 'tarjeta', diferencia: -500), [
        MedioDiferencia.efectivo,
        MedioDiferencia.tarjeta,
      ]);
      expect(mediosPermitidos(metodoOriginal: 'mixto', diferencia: -500), [
        MedioDiferencia.efectivo,
        MedioDiferencia.tarjeta,
      ]);
    });
  });

  group('datosDeCambio y el cierre de caja', () {
    Map<String, dynamic> cambio(
      Producto nuevo,
      MedioDiferencia? medio, {
      int recibido = 0,
    }) => datosDeCambio(
      calculo: CalculoCambio(
        itemDevuelto: _item('latte', 'Café latte', 1, 2000),
        unidades: 1,
        productoNuevo: nuevo,
      ),
      medio: medio,
      efectivoRecibido: recibido,
      ventaOriginalId: 'v1',
      turnoId: 't1',
      sucursalId: 's1',
    );

    Map<String, dynamic> conFecha(Map<String, dynamic> datos) => {
      ...datos,
      'fecha': Timestamp.fromDate(DateTime(2026, 9, 21, 10)),
    };

    test('cobrar en efectivo: entra plata a la caja, con vuelto', () {
      final d = cambio(_mocha, MedioDiferencia.efectivo, recibido: 1000);
      expect(d['total'], 500);
      expect(d['metodoPago'], 'efectivo');
      expect(d['montoEfectivo'], 500);
      expect(d['vuelto'], 500);
      expect(d['esCambio'], isTrue);
      expect(d['ventaOriginalId'], 'v1');
    });

    test('devolver en efectivo: sale plata de la caja (monto negativo)', () {
      final d = cambio(_barra, MedioDiferencia.efectivo);
      expect(d['total'], -1200);
      expect(d['montoEfectivo'], -1200);
      expect(d['vuelto'], 0);
    });

    test('cobrar con tarjeta no toca el efectivo', () {
      final d = cambio(_mocha, MedioDiferencia.tarjeta);
      expect(d['metodoPago'], 'tarjeta');
      expect(d['montoEfectivo'], 0);
    });

    test('mismo precio: no mueve plata aunque se elija un medio', () {
      const otro = Producto(
        id: 'x',
        codigoBarras: '9',
        nombre: 'Otro sabor',
        precio: 2000,
      );
      final d = cambio(otro, MedioDiferencia.tarjeta);
      expect(d['total'], 0);
      expect(d['montoEfectivo'], 0);
      expect(d['metodoPago'], 'efectivo');
    });

    test('a la deuda del cliente: queda como crédito', () {
      final d = cambio(_mocha, MedioDiferencia.deuda);
      expect(d['metodoPago'], 'credito');
      expect(d['montoEfectivo'], 0);
    });

    test('el resumen del turno suma el cambio sin contarlo como venta', () {
      final venta = {
        'total': 2000,
        'metodoPago': 'efectivo',
        'montoEfectivo': 2000,
        'sucursalId': 's1',
        'fecha': Timestamp.fromDate(DateTime(2026, 9, 21, 9)),
        'items': [_item('latte', 'Café latte', 1, 2000).aMapa()],
      };
      final soloVenta = resumirVentas([venta]);
      expect(soloVenta.efectivoEnCaja, 2000);

      // Cambia el latte por un mocha y paga 500 en efectivo.
      final conCobro = resumirVentas([
        venta,
        conFecha(cambio(_mocha, MedioDiferencia.efectivo, recibido: 500)),
      ]);
      expect(conCobro.total, 2500);
      expect(conCobro.efectivoEnCaja, 2500);
      expect(conCobro.cantidadVentas, 1); // el cambio no es otra venta
      expect(conCobro.vendidoEfectivo, 2500);
      // El latte se descuenta y el mocha se suma.
      expect(conCobro.unidadesPorProducto['Café latte'], 0);
      expect(conCobro.unidadesPorProducto['Café mocha'], 1);

      // Cambia el latte por una barra y se le devuelven 1.200 en efectivo.
      final conDevolucion = resumirVentas([
        venta,
        conFecha(cambio(_barra, MedioDiferencia.efectivo)),
      ]);
      expect(conDevolucion.total, 800);
      expect(conDevolucion.efectivoEnCaja, 800);
      expect(conDevolucion.vendidoEfectivo, 800);
    });

    test('devolver a la tarjeta reduce lo vendido con tarjeta', () {
      final venta = {
        'total': 2000,
        'metodoPago': 'tarjeta',
        'montoEfectivo': 0,
        'sucursalId': 's1',
        'fecha': Timestamp.fromDate(DateTime(2026, 9, 21, 9)),
        'items': [_item('latte', 'Café latte', 1, 2000).aMapa()],
      };
      final r = resumirVentas([
        venta,
        conFecha(cambio(_barra, MedioDiferencia.tarjeta)),
      ]);
      expect(r.total, 800);
      expect(r.vendidoTarjeta, 800);
      expect(r.efectivoEnCaja, 0);
    });
  });
}
