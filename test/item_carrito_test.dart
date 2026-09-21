import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/models/item_carrito.dart';
import 'package:cafeteria_sistema/models/producto.dart';

Producto _producto({
  int precio = 400,
  int promoCantidad = 0,
  int promoPrecioPack = 0,
}) => Producto(
  id: 'p1',
  codigoBarras: '123',
  nombre: 'Galleta',
  precio: precio,
  promoCantidad: promoCantidad,
  promoPrecioPack: promoPrecioPack,
);

int _subtotal(Producto producto, int cantidad) =>
    ItemCarrito(producto: producto, cantidad: cantidad).subtotal;

void main() {
  group('Sin promoción', () {
    test('subtotal es precio por cantidad y no hay ahorro', () {
      final item = ItemCarrito(producto: _producto(precio: 750), cantidad: 4);
      expect(item.subtotal, 3000);
      expect(item.subtotalSinPromo, 3000);
      expect(item.ahorro, 0);
    });

    test('la cantidad por defecto es 1', () {
      expect(ItemCarrito(producto: _producto(precio: 750)).subtotal, 750);
    });

    test('cantidad 0 cuesta 0', () {
      expect(_subtotal(_producto(), 0), 0);
    });
  });

  group('Promo "cada 3 por \$1.000" (unitario \$400)', () {
    final producto = _producto(
      precio: 400,
      promoCantidad: 3,
      promoPrecioPack: 1000,
    );

    test('reconoce la promo como válida', () {
      expect(producto.tienePromo, isTrue);
    });

    test('bajo el pack se cobra a precio unitario', () {
      expect(_subtotal(producto, 1), 400);
      expect(_subtotal(producto, 2), 800);
    });

    test('un pack completo cuesta el precio del pack', () {
      expect(_subtotal(producto, 3), 1000);
    });

    test('un pack más sobrantes: pack + unitarios', () {
      expect(_subtotal(producto, 4), 1400);
      expect(_subtotal(producto, 5), 1800);
    });

    test('varios packs', () {
      expect(_subtotal(producto, 6), 2000);
      expect(_subtotal(producto, 7), 2400);
      expect(_subtotal(producto, 9), 3000);
      expect(_subtotal(producto, 30), 10000);
    });

    test('el ahorro es lo que se dejaría de pagar sin promo', () {
      expect(ItemCarrito(producto: producto, cantidad: 2).ahorro, 0);
      expect(ItemCarrito(producto: producto, cantidad: 3).ahorro, 200);
      expect(ItemCarrito(producto: producto, cantidad: 7).ahorro, 400);
    });

    test('la promo nunca cobra más que el precio sin promo', () {
      for (var cantidad = 0; cantidad <= 100; cantidad++) {
        final item = ItemCarrito(producto: producto, cantidad: cantidad);
        expect(item.subtotal, lessThanOrEqualTo(item.subtotalSinPromo));
        expect(item.ahorro, greaterThanOrEqualTo(0));
        expect(item.subtotal + item.ahorro, item.subtotalSinPromo);
      }
    });
  });

  group('Promos inválidas se ignoran (no regalan ni encarecen)', () {
    test('pack igual al precio sin promo', () {
      final producto = _producto(
        precio: 400,
        promoCantidad: 3,
        promoPrecioPack: 1200,
      );
      expect(producto.tienePromo, isFalse);
      expect(_subtotal(producto, 3), 1200);
    });

    test('pack más caro que comprar suelto', () {
      final producto = _producto(
        precio: 400,
        promoCantidad: 3,
        promoPrecioPack: 1500,
      );
      expect(producto.tienePromo, isFalse);
      expect(_subtotal(producto, 3), 1200);
    });

    test('cantidad de promo en 0 no divide por cero', () {
      final producto = _producto(
        precio: 400,
        promoCantidad: 0,
        promoPrecioPack: 1000,
      );
      expect(producto.tienePromo, isFalse);
      expect(_subtotal(producto, 5), 2000);
    });

    test('precio de pack en 0 no deja el producto gratis', () {
      final producto = _producto(
        precio: 400,
        promoCantidad: 3,
        promoPrecioPack: 0,
      );
      expect(producto.tienePromo, isFalse);
      expect(_subtotal(producto, 3), 1200);
    });
  });

  group('Otras promos', () {
    test('cada 2 por \$1.500 con unitario \$1.000', () {
      final producto = _producto(
        precio: 1000,
        promoCantidad: 2,
        promoPrecioPack: 1500,
      );
      expect(_subtotal(producto, 1), 1000);
      expect(_subtotal(producto, 2), 1500);
      expect(_subtotal(producto, 3), 2500);
      expect(_subtotal(producto, 4), 3000);
    });

    test('el pack no depende del precio unitario (2 por \$1.000)', () {
      final producto = _producto(
        precio: 700,
        promoCantidad: 2,
        promoPrecioPack: 1000,
      );
      expect(_subtotal(producto, 2), 1000);
      expect(_subtotal(producto, 5), 2700);
    });
  });
}
