import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/models/cliente.dart';
import 'package:cafeteria_sistema/utils/calculo_pago.dart';

Cliente _cliente({int limite = 20000, int deuda = 5000}) => Cliente(
  id: 'c1',
  grupoClientesId: 'g1',
  nombre: 'Ana',
  limiteCredito: limite,
  deuda: deuda,
);

void main() {
  group('Efectivo', () {
    test('paga de más: hay vuelto y a la caja entra solo el total', () {
      const pago = CalculoPago(
        metodo: MetodoPago.efectivo,
        total: 12500,
        efectivoIngresado: 20000,
      );
      expect(pago.recibido, 20000);
      expect(pago.vuelto, 7500);
      expect(pago.vueltoAEntregar, 7500);
      expect(pago.montoEfectivo, 12500);
      expect(pago.puedeConfirmar, isTrue);
    });

    test('paga justo: sin vuelto', () {
      const pago = CalculoPago(
        metodo: MetodoPago.efectivo,
        total: 12500,
        efectivoIngresado: 12500,
      );
      expect(pago.vuelto, 0);
      expect(pago.vueltoAEntregar, 0);
      expect(pago.puedeConfirmar, isTrue);
    });

    test('paga de menos: falta plata y no se puede confirmar', () {
      const pago = CalculoPago(
        metodo: MetodoPago.efectivo,
        total: 12500,
        efectivoIngresado: 10000,
      );
      expect(pago.vuelto, -2500);
      expect(pago.vueltoAEntregar, 0);
      expect(pago.puedeConfirmar, isFalse);
    });

    test('sin monto ingresado no se puede confirmar', () {
      const pago = CalculoPago(metodo: MetodoPago.efectivo, total: 500);
      expect(pago.puedeConfirmar, isFalse);
    });
  });

  group('Tarjeta', () {
    test('cubre el total exacto: sin vuelto y sin efectivo en caja', () {
      const pago = CalculoPago(metodo: MetodoPago.tarjeta, total: 8000);
      expect(pago.recibido, 8000);
      expect(pago.vuelto, 0);
      expect(pago.vueltoAEntregar, 0);
      expect(pago.montoEfectivo, 0);
      expect(pago.puedeConfirmar, isTrue);
    });

    test('ignora lo que haya quedado escrito en los campos de efectivo', () {
      const pago = CalculoPago(
        metodo: MetodoPago.tarjeta,
        total: 8000,
        efectivoIngresado: 50000,
        tarjetaIngresada: 999,
      );
      expect(pago.vuelto, 0);
      expect(pago.montoEfectivo, 0);
    });
  });

  group('Mixto', () {
    test('efectivo + tarjeta = total: sin vuelto', () {
      const pago = CalculoPago(
        metodo: MetodoPago.mixto,
        total: 10000,
        efectivoIngresado: 5000,
        tarjetaIngresada: 5000,
      );
      expect(pago.recibido, 10000);
      expect(pago.vuelto, 0);
      expect(pago.montoEfectivo, 5000);
      expect(pago.puedeConfirmar, isTrue);
    });

    test('se pasan de efectivo: el vuelto sale del efectivo', () {
      const pago = CalculoPago(
        metodo: MetodoPago.mixto,
        total: 10000,
        efectivoIngresado: 5000,
        tarjetaIngresada: 8000,
      );
      expect(pago.vuelto, 3000);
      expect(pago.vueltoAEntregar, 3000);
      // Entraron $5.000, se devuelven $3.000: quedan $2.000 en la caja.
      expect(pago.montoEfectivo, 2000);
      expect(pago.puedeConfirmar, isTrue);
    });

    test('falta plata: no se puede confirmar', () {
      const pago = CalculoPago(
        metodo: MetodoPago.mixto,
        total: 10000,
        efectivoIngresado: 2000,
        tarjetaIngresada: 5000,
      );
      expect(pago.vuelto, -3000);
      expect(pago.puedeConfirmar, isFalse);
    });

    test('la tarjeta no puede pasar del total, aunque el efectivo sea 0', () {
      const pago = CalculoPago(
        metodo: MetodoPago.mixto,
        total: 10000,
        tarjetaIngresada: 12000,
      );
      expect(pago.recibido, greaterThanOrEqualTo(10000));
      expect(pago.puedeConfirmar, isFalse);
    });

    test('todo con tarjeta dentro de un mixto: nada de efectivo en caja', () {
      const pago = CalculoPago(
        metodo: MetodoPago.mixto,
        total: 10000,
        tarjetaIngresada: 10000,
      );
      expect(pago.montoEfectivo, 0);
      expect(pago.vuelto, 0);
      expect(pago.puedeConfirmar, isTrue);
    });

    test('en cualquier pago mixto válido, el efectivo en caja es lo entregado '
        'menos el vuelto', () {
      const total = 9700;
      for (var tarjeta = 0; tarjeta <= total; tarjeta += 700) {
        for (var efectivo = 0; efectivo <= 20000; efectivo += 500) {
          final pago = CalculoPago(
            metodo: MetodoPago.mixto,
            total: total,
            efectivoIngresado: efectivo,
            tarjetaIngresada: tarjeta,
          );
          if (!pago.puedeConfirmar) continue;
          expect(
            pago.montoEfectivo,
            efectivo - pago.vueltoAEntregar,
            reason: 'efectivo=$efectivo tarjeta=$tarjeta',
          );
          expect(pago.montoEfectivo, greaterThanOrEqualTo(0));
        }
      }
    });
  });

  group('Crédito', () {
    test('cabe dentro del límite disponible', () {
      final pago = CalculoPago(
        metodo: MetodoPago.credito,
        total: 12000,
        cliente: _cliente(limite: 20000, deuda: 5000),
      );
      expect(pago.vuelto, 0);
      expect(pago.montoEfectivo, 0);
      expect(pago.puedeConfirmar, isTrue);
    });

    test('llegar justo al límite está permitido', () {
      final pago = CalculoPago(
        metodo: MetodoPago.credito,
        total: 15000,
        cliente: _cliente(limite: 20000, deuda: 5000),
      );
      expect(pago.puedeConfirmar, isTrue);
    });

    test('pasarse del límite por un peso no está permitido', () {
      final pago = CalculoPago(
        metodo: MetodoPago.credito,
        total: 15001,
        cliente: _cliente(limite: 20000, deuda: 5000),
      );
      expect(pago.puedeConfirmar, isFalse);
    });

    test('sin cliente elegido no se puede confirmar', () {
      const pago = CalculoPago(metodo: MetodoPago.credito, total: 1000);
      expect(pago.puedeConfirmar, isFalse);
    });

    test('un cliente que ya está sobre su límite no puede fiar más', () {
      final pago = CalculoPago(
        metodo: MetodoPago.credito,
        total: 1,
        cliente: _cliente(limite: 10000, deuda: 10000),
      );
      expect(pago.puedeConfirmar, isFalse);
    });
  });
}
