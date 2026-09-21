import '../models/cliente.dart';

enum MetodoPago { efectivo, tarjeta, mixto, credito }

/// Cálculo de un cobro: cuánto se recibió, cuánto vuelto hay que entregar,
/// cuánto efectivo queda realmente en la caja y si el pago se puede confirmar.
///
/// Es lógica pura (sin Flutter ni Firebase) para poder probarla: de esto
/// depende que la caja cuadre.
class CalculoPago {
  final MetodoPago metodo;
  final int total;

  /// Lo que la persona entregó en billetes y monedas (efectivo y mixto).
  final int efectivoIngresado;

  /// Lo que se pasó por el terminal de tarjeta (solo en mixto).
  final int tarjetaIngresada;

  /// Cliente al que se le fía (solo en crédito).
  final Cliente? cliente;

  const CalculoPago({
    required this.metodo,
    required this.total,
    this.efectivoIngresado = 0,
    this.tarjetaIngresada = 0,
    this.cliente,
  });

  /// Dinero total recibido. Tarjeta y crédito cubren exactamente el total.
  int get recibido => switch (metodo) {
    MetodoPago.efectivo => efectivoIngresado,
    MetodoPago.tarjeta => total,
    MetodoPago.mixto => efectivoIngresado + tarjetaIngresada,
    MetodoPago.credito => total,
  };

  /// Recibido menos total: positivo es vuelto, negativo es lo que falta.
  int get vuelto => recibido - total;

  int get vueltoAEntregar => vuelto > 0 ? vuelto : 0;

  /// Cuánto efectivo queda de verdad en la caja por esta venta. En una venta
  /// mixta el vuelto siempre sale del efectivo, así que es el total menos lo
  /// pagado con tarjeta.
  int get montoEfectivo => switch (metodo) {
    MetodoPago.efectivo => total,
    MetodoPago.mixto => total - tarjetaIngresada,
    MetodoPago.tarjeta || MetodoPago.credito => 0,
  };

  bool get puedeConfirmar => switch (metodo) {
    MetodoPago.efectivo => recibido >= total,
    MetodoPago.tarjeta => true,
    // La tarjeta no puede cubrir más que el total: el resto siempre se paga
    // (y se vuelve) en efectivo.
    MetodoPago.mixto => recibido >= total && tarjetaIngresada <= total,
    MetodoPago.credito =>
      cliente != null && cliente!.deuda + total <= cliente!.limiteCredito,
  };
}
