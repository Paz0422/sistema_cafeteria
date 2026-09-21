import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/models/producto.dart';
import 'package:cafeteria_sistema/utils/busqueda_productos.dart';

Producto _p(String nombre) =>
    Producto(id: nombre, codigoBarras: '1', nombre: nombre, precio: 1000);

final _catalogo = [
  _p('Café latte'),
  _p('Café americano'),
  _p('Té verde'),
  _p('Jugo de piña'),
  _p('Sándwich de pollo'),
  _p('Barra de cereal'),
];

List<String> _buscar(String consulta, {int maximo = 8}) =>
    buscarProductosPorNombre(
      _catalogo,
      consulta,
      maximo: maximo,
    ).map((p) => p.nombre).toList();

void main() {
  test('ignora mayúsculas y tildes', () {
    expect(_buscar('CAFE'), ['Café americano', 'Café latte']);
    expect(_buscar('pina'), ['Jugo de piña']);
    expect(_buscar('sandwich'), ['Sándwich de pollo']);
    expect(_buscar('te'), contains('Té verde'));
  });

  test('todas las palabras deben estar, en cualquier orden', () {
    expect(_buscar('latte cafe'), ['Café latte']);
    expect(_buscar('pollo sandwich'), ['Sándwich de pollo']);
    expect(_buscar('cafe pollo'), isEmpty);
  });

  test('los que empiezan con lo escrito van primero', () {
    // "de" aparece en tres nombres, pero ninguno empieza con "de".
    expect(_buscar('barra'), ['Barra de cereal']);
    final orden = _buscar('a'); // todos tienen "a"
    expect(orden.first, 'Barra de cereal');
  });

  test('sin texto no devuelve nada y respeta el máximo', () {
    expect(_buscar(''), isEmpty);
    expect(_buscar('   '), isEmpty);
    expect(_buscar('a', maximo: 2).length, 2);
  });

  test('sin coincidencias devuelve una lista vacía', () {
    expect(_buscar('zzz'), isEmpty);
  });
}
