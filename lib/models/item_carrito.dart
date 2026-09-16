import 'producto.dart';

class ItemCarrito {
  final Producto producto;
  int cantidad;

  ItemCarrito({required this.producto, this.cantidad = 1});

  int get subtotalSinPromo => producto.precio * cantidad;

  int get subtotal {
    if (!producto.tienePromo) return subtotalSinPromo;
    final grupos = cantidad ~/ producto.promoCantidad;
    final resto = cantidad % producto.promoCantidad;
    return grupos * producto.promoPrecioPack + resto * producto.precio;
  }

  int get ahorro => subtotalSinPromo - subtotal;
}
