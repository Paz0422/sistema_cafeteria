import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cafeteria_sistema/models/cuenta_abierta.dart';
import 'package:cafeteria_sistema/models/item_carrito.dart';
import 'package:cafeteria_sistema/models/producto.dart';
import 'package:cafeteria_sistema/utils/cuentas_guardadas.dart';

const _latte = Producto(
  id: 'p1',
  codigoBarras: '111',
  nombre: 'Café latte',
  precio: 2400,
);

const _sandwich = Producto(
  id: 'p2',
  codigoBarras: '222',
  nombre: 'Sándwich',
  precio: 3500,
  promoCantidad: 2,
  promoPrecioPack: 6000,
  controlaStock: false,
);

List<CuentaAbierta> _cuentas() => [
  CuentaAbierta(
    id: '0',
    nombre: 'Cuenta 1',
    carrito: [ItemCarrito(producto: _latte, cantidad: 2)],
  ),
  CuentaAbierta(
    id: '2-99',
    nombre: 'Cuenta 3',
    carrito: [
      ItemCarrito(producto: _sandwich, cantidad: 3),
      ItemCarrito(producto: _latte),
    ],
  ),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lo guardado se recupera igual: cuentas, cantidades y promos', () async {
    await guardarCuentas(
      'turno-1',
      cuentas: _cuentas(),
      indiceActivo: 1,
      contador: 3,
    );

    final recuperado = await cargarCuentas('turno-1');
    expect(recuperado, isNotNull);
    expect(recuperado!.indiceActivo, 1);
    expect(recuperado.contador, 3);
    expect(recuperado.cuentas.map((c) => c.nombre), ['Cuenta 1', 'Cuenta 3']);

    final segunda = recuperado.cuentas[1];
    expect(segunda.id, '2-99');
    expect(segunda.carrito.length, 2);
    expect(segunda.carrito[0].producto.nombre, 'Sándwich');
    expect(segunda.carrito[0].cantidad, 3);
    expect(segunda.carrito[0].producto.controlaStock, isFalse);
    // 3 sándwiches con promo 2 x 6.000: un pack y una unidad suelta.
    expect(segunda.carrito[0].subtotal, 6000 + 3500);
    expect(recuperado.cuentas[0].carrito.single.cantidad, 2);
  });

  test('cada turno guarda lo suyo', () async {
    await guardarCuentas(
      'turno-1',
      cuentas: _cuentas(),
      indiceActivo: 0,
      contador: 3,
    );
    expect(await cargarCuentas('turno-2'), isNull);
  });

  test('una sola cuenta vacía no deja nada guardado', () async {
    await guardarCuentas(
      'turno-1',
      cuentas: _cuentas(),
      indiceActivo: 0,
      contador: 3,
    );
    await guardarCuentas(
      'turno-1',
      cuentas: [CuentaAbierta(id: '0', nombre: 'Cuenta 1')],
      indiceActivo: 0,
      contador: 1,
    );
    expect(await cargarCuentas('turno-1'), isNull);
  });

  test('borrarCuentas elimina lo guardado', () async {
    await guardarCuentas(
      'turno-1',
      cuentas: _cuentas(),
      indiceActivo: 0,
      contador: 3,
    );
    await borrarCuentas('turno-1');
    expect(await cargarCuentas('turno-1'), isNull);
  });

  test('datos dañados se ignoran en vez de romper la venta', () async {
    SharedPreferences.setMockInitialValues({
      'cuentas_turno_turno-1': '{esto no es json',
      'cuentas_turno_turno-2': '{"cuentas": "raro"}',
    });
    expect(await cargarCuentas('turno-1'), isNull);
    expect(await cargarCuentas('turno-2'), isNull);
  });

  test('un índice activo fuera de rango se corrige', () {
    final json = cuentasAJson(
      cuentas: _cuentas(),
      indiceActivo: 9,
      contador: 3,
    );
    expect(cuentasDeJson(json)!.indiceActivo, 1);
  });
}
