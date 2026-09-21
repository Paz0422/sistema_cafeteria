import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/models/cliente.dart';
import 'package:cafeteria_sistema/pos/dialogo_pago.dart';
import 'package:cafeteria_sistema/utils/calculo_pago.dart';

// El diálogo de cobro de punta a punta: lo que se escribe en pantalla, lo que
// muestra y el ResultadoPago que devuelve (que es lo que se guarda en la venta).

const _total = 12500;

/// Abre el diálogo y devuelve una función para leer su resultado al cerrarse.
Future<ResultadoPago? Function()> _abrir(
  WidgetTester tester, {
  Future<Cliente?> Function(BuildContext)? elegirCliente,
}) async {
  ResultadoPago? resultado;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultado = await showDialog<ResultadoPago>(
                context: context,
                builder: (_) => DialogoPago(
                  total: _total,
                  grupoClientesId: 'g',
                  // Sin Firebase: por defecto nadie se elige.
                  elegirCliente: elegirCliente ?? (_) async => null,
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return () => resultado;
}

Future<void> _escribir(WidgetTester tester, String campo, String valor) async {
  await tester.enterText(find.widgetWithText(TextField, campo), valor);
  await tester.pump();
}

bool _confirmarHabilitado(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirmar pago'),
        )
        .onPressed !=
    null;

Future<void> _confirmar(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pago'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Efectivo: muestra el vuelto y devuelve el resultado correcto', (
    tester,
  ) async {
    final resultado = await _abrir(tester);

    await _escribir(tester, 'Monto en efectivo', '20000');

    expect(find.text('Vuelto: \$7.500'), findsOneWidget);
    expect(_confirmarHabilitado(tester), isTrue);

    await _confirmar(tester);
    final pago = resultado()!;
    expect(pago.metodo, MetodoPago.efectivo);
    expect(pago.vuelto, 7500);
    expect(pago.montoEfectivo, _total);
  });

  testWidgets('Efectivo insuficiente: no deja confirmar', (tester) async {
    await _abrir(tester);

    expect(_confirmarHabilitado(tester), isFalse);

    await _escribir(tester, 'Monto en efectivo', '10000');
    expect(_confirmarHabilitado(tester), isFalse);

    await _escribir(tester, 'Monto en efectivo', '12500');
    expect(_confirmarHabilitado(tester), isTrue);
  });

  testWidgets('Tarjeta: cobra el total sin vuelto ni efectivo en caja', (
    tester,
  ) async {
    final resultado = await _abrir(tester);

    await tester.tap(find.text('Tarjeta'));
    await tester.pumpAndSettle();
    await _confirmar(tester);

    final pago = resultado()!;
    expect(pago.metodo, MetodoPago.tarjeta);
    expect(pago.vuelto, 0);
    expect(pago.montoEfectivo, 0);
  });

  testWidgets('Mixto: el vuelto sale del efectivo y la caja lo refleja', (
    tester,
  ) async {
    final resultado = await _abrir(tester);

    await tester.tap(find.text('Mixto'));
    await tester.pumpAndSettle();
    await _escribir(tester, 'Monto en efectivo', '5000');
    await _escribir(tester, 'Monto con tarjeta', '11000');

    // Recibido 16.000 sobre 12.500: vuelto 3.500.
    expect(find.text('Vuelto: \$3.500'), findsOneWidget);

    await _confirmar(tester);
    final pago = resultado()!;
    expect(pago.metodo, MetodoPago.mixto);
    expect(pago.vuelto, 3500);
    // Entraron $5.000 en efectivo, se devuelven $3.500: quedan $1.500.
    expect(pago.montoEfectivo, 1500);
  });

  testWidgets('Mixto: avisa cuánto falta y no deja confirmar', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Mixto'));
    await tester.pumpAndSettle();
    await _escribir(tester, 'Monto en efectivo', '2000');
    await _escribir(tester, 'Monto con tarjeta', '5000');

    expect(find.text('Falta: \$5.500'), findsOneWidget);
    expect(_confirmarHabilitado(tester), isFalse);
  });

  testWidgets('Mixto: la tarjeta no puede superar el total', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Mixto'));
    await tester.pumpAndSettle();
    await _escribir(tester, 'Monto con tarjeta', '13000');

    expect(_confirmarHabilitado(tester), isFalse);
  });

  testWidgets('Crédito: sin cliente elegido no deja confirmar', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Crédito'));
    await tester.pumpAndSettle();

    expect(_confirmarHabilitado(tester), isFalse);
  });

  testWidgets('Crédito abre la lista de clientes de inmediato', (tester) async {
    var aperturas = 0;
    final resultado = await _abrir(
      tester,
      elegirCliente: (_) async {
        aperturas++;
        return const Cliente(
          id: 'c1',
          grupoClientesId: 'g',
          nombre: 'María González',
          limiteCredito: 50000,
          deuda: 10000,
        );
      },
    );

    await tester.tap(find.text('Crédito'));
    await tester.pumpAndSettle();

    expect(aperturas, 1);
    expect(find.textContaining('María González'), findsOneWidget);
    expect(_confirmarHabilitado(tester), isTrue);

    await tester.tap(find.text('Confirmar pago'));
    await tester.pumpAndSettle();
    expect(resultado()!.metodo, MetodoPago.credito);
    expect(resultado()!.cliente!.id, 'c1');
  });

  testWidgets(
    'Si se cierra la lista sin elegir, queda el botón para reintentar',
    (tester) async {
      await _abrir(tester);

      await tester.tap(find.text('Crédito'));
      await tester.pumpAndSettle();

      expect(find.text('Elegir cliente'), findsOneWidget);
      expect(_confirmarHabilitado(tester), isFalse);
    },
  );

  testWidgets('Enter en el monto en efectivo confirma el pago', (tester) async {
    final resultado = await _abrir(tester);

    await _escribir(tester, 'Monto en efectivo', '20.000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(resultado()?.metodo, MetodoPago.efectivo);
    expect(resultado()?.vuelto, 20000 - _total);
  });

  testWidgets('Cancelar cierra el diálogo sin resultado', (tester) async {
    final resultado = await _abrir(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(resultado(), isNull);
  });
}
