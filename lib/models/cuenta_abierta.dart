import 'item_carrito.dart';

class CuentaAbierta {
  final String id;
  String nombre;
  final List<ItemCarrito> carrito;

  CuentaAbierta({
    required this.id,
    required this.nombre,
    List<ItemCarrito>? carrito,
  }) : carrito = carrito ?? [];
}
