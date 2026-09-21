import '../models/item_carrito.dart';
import '../models/producto.dart';

/// Un producto de una venta, tal como se guarda en `ventas.items`.
class ItemVenta {
  final String productoId;
  final String nombre;
  final int cantidad;
  final int precioUnitario;

  /// Lo que costaron esas unidades en total (con promo, si la había).
  final int subtotal;

  const ItemVenta({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory ItemVenta.deMapa(Map<String, dynamic> m) => ItemVenta(
    productoId: m['productoId'] as String? ?? '',
    nombre: m['nombre'] as String? ?? '',
    cantidad: (m['cantidad'] as num?)?.toInt() ?? 0,
    precioUnitario: (m['precioUnitario'] as num?)?.toInt() ?? 0,
    subtotal: (m['subtotal'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> aMapa() => {
    'productoId': productoId,
    'nombre': nombre,
    'cantidad': cantidad,
    'precioUnitario': precioUnitario,
    'subtotal': subtotal,
  };
}

/// Lo que la persona tiene hoy de una venta: los productos originales más lo
/// que cambiaron después. Cada cambio guarda el producto devuelto con
/// cantidad negativa y el que se lleva con cantidad positiva, así que basta
/// sumar por producto y descartar los que quedaron en cero.
List<ItemVenta> itemsNetos(
  Iterable<Map<String, dynamic>> itemsOriginales,
  Iterable<Iterable<Map<String, dynamic>>> itemsDeCambios,
) {
  final porProducto = <String, ItemVenta>{};

  void sumar(Map<String, dynamic> crudo) {
    final item = ItemVenta.deMapa(crudo);
    final previo = porProducto[item.productoId];
    porProducto[item.productoId] = ItemVenta(
      productoId: item.productoId,
      nombre: item.nombre,
      cantidad: (previo?.cantidad ?? 0) + item.cantidad,
      precioUnitario: item.precioUnitario,
      subtotal: (previo?.subtotal ?? 0) + item.subtotal,
    );
  }

  itemsOriginales.forEach(sumar);
  for (final cambio in itemsDeCambios) {
    cambio.forEach(sumar);
  }
  return porProducto.values.where((i) => i.cantidad > 0).toList();
}

/// Cuánto vale devolver [unidades] de [item]. Si el producto tenía promo no
/// se puede reconstruir el pack, así que se reparte lo pagado en partes
/// iguales entre las unidades.
int valorDeDevolucion(ItemVenta item, int unidades) {
  if (item.cantidad <= 0) return 0;
  if (unidades >= item.cantidad) return item.subtotal;
  if (item.subtotal == item.precioUnitario * item.cantidad) {
    return item.precioUnitario * unidades;
  }
  return (item.subtotal * unidades / item.cantidad).round();
}

/// Cómo se salda la diferencia de un cambio.
enum MedioDiferencia {
  efectivo('Efectivo'),
  tarjeta('Tarjeta'),
  deuda('A la deuda del cliente');

  final String etiqueta;
  const MedioDiferencia(this.etiqueta);
}

/// Formas válidas de saldar la diferencia según cómo se pagó la venta.
/// - Una venta a crédito solo mueve la deuda del cliente.
/// - Cobrar (diferencia positiva) se puede en efectivo o con tarjeta.
/// - Devolver plata solo por donde pagó: siempre efectivo desde la caja, y a
///   la tarjeta únicamente si la venta se pagó (aunque sea en parte) con ella.
List<MedioDiferencia> mediosPermitidos({
  required String metodoOriginal,
  required int diferencia,
}) {
  if (diferencia == 0) return const [];
  if (metodoOriginal == 'credito') return const [MedioDiferencia.deuda];
  if (diferencia > 0) {
    return const [MedioDiferencia.efectivo, MedioDiferencia.tarjeta];
  }
  return [
    MedioDiferencia.efectivo,
    if (metodoOriginal == 'tarjeta' || metodoOriginal == 'mixto')
      MedioDiferencia.tarjeta,
  ];
}

/// El cálculo de un cambio de producto: qué se devuelve, qué se lleva y cuánto
/// hay que cobrar o devolver.
class CalculoCambio {
  final ItemVenta itemDevuelto;
  final int unidades;
  final Producto productoNuevo;

  const CalculoCambio({
    required this.itemDevuelto,
    required this.unidades,
    required this.productoNuevo,
  });

  int get valorDevuelto => valorDeDevolucion(itemDevuelto, unidades);

  int get valorNuevo =>
      ItemCarrito(producto: productoNuevo, cantidad: unidades).subtotal;

  /// Positiva: el cliente paga la diferencia. Negativa: se le devuelve.
  int get diferencia => valorNuevo - valorDevuelto;

  /// Los dos productos del cambio, listos para `ventas.items`: el que vuelve
  /// con cantidad negativa y el que se lleva con cantidad positiva.
  List<Map<String, dynamic>> get items => [
    ItemVenta(
      productoId: itemDevuelto.productoId,
      nombre: itemDevuelto.nombre,
      cantidad: -unidades,
      precioUnitario: itemDevuelto.precioUnitario,
      subtotal: -valorDevuelto,
    ).aMapa(),
    ItemVenta(
      productoId: productoNuevo.id,
      nombre: productoNuevo.nombre,
      cantidad: unidades,
      precioUnitario: productoNuevo.precio,
      subtotal: valorNuevo,
    ).aMapa(),
  ];
}

/// Lo que se guarda en `ventas` por un cambio. Es un registro nuevo (la venta
/// original no se toca) que suma o resta la diferencia, así el cierre de caja
/// cuadra: el efectivo que entra o sale queda en `montoEfectivo`, con signo.
Map<String, dynamic> datosDeCambio({
  required CalculoCambio calculo,
  required MedioDiferencia? medio,
  required int efectivoRecibido,
  required String ventaOriginalId,
  required String turnoId,
  required String sucursalId,
  String? clienteId,
  String? clienteNombre,
}) {
  final diferencia = calculo.diferencia;
  final medioFinal = diferencia == 0 ? null : medio;
  final enEfectivo = medioFinal == MedioDiferencia.efectivo;

  return {
    'esCambio': true,
    'ventaOriginalId': ventaOriginalId,
    'turnoId': turnoId,
    'sucursalId': sucursalId,
    'total': diferencia,
    'metodoPago': switch (medioFinal) {
      MedioDiferencia.tarjeta => 'tarjeta',
      MedioDiferencia.deuda => 'credito',
      _ => 'efectivo',
    },
    'montoEfectivo': enEfectivo ? diferencia : 0,
    // Solo hay vuelto cuando el cliente paga de más en efectivo.
    'vuelto': enEfectivo && diferencia > 0 && efectivoRecibido > diferencia
        ? efectivoRecibido - diferencia
        : 0,
    'clienteId': clienteId,
    'clienteNombre': clienteNombre,
    'items': calculo.items,
  };
}
