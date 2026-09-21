import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/models/producto.dart';
import 'package:cafeteria_sistema/pos/dialogo_cambio.dart';
import 'package:cafeteria_sistema/theme/marca.dart';
import 'package:cafeteria_sistema/utils/cambio_venta.dart';

const _latte = ItemVenta(
  productoId: 'latte',
  nombre: 'Café latte',
  cantidad: 1,
  precioUnitario: 2000,
  subtotal: 2000,
);

const _vainilla = Producto(
  id: 'vainilla',
  codigoBarras: '1',
  nombre: 'Latte vainilla',
  precio: 2000,
);
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

class _Guardado {
  CalculoCambio? calculo;
  MedioDiferencia? medio;
  int? recibido;
  bool? resultado;
}

/// Abre el diálogo con el producto nuevo ya elegido por [nuevo].
Future<_Guardado> _abrir(
  WidgetTester tester, {
  required Producto nuevo,
  String metodoOriginal = 'efectivo',
  List<ItemVenta> items = const [_latte],
}) async {
  tester.view.physicalSize = const Size(900, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final g = _Guardado();
  await tester.pumpWidget(
    MaterialApp(
      theme: temaFusion(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              g.resultado = await showDialog<bool>(
                context: context,
                builder: (_) => DialogoCambio(
                  ventaId: 'v1',
                  turnoId: 't1',
                  sucursalId: 's1',
                  vendedorNombre: 'Julio',
                  metodoOriginal: metodoOriginal,
                  clienteNombre: 'María',
                  items: items,
                  elegirProducto: (_) async => nuevo,
                  guardar: (calculo, medio, recibido) async {
                    g.calculo = calculo;
                    g.medio = medio;
                    g.recibido = recibido;
                  },
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
  return g;
}

Future<void> _elegirProducto(WidgetTester tester) async {
  await tester.tap(find.text('Elegir producto'));
  await tester.pumpAndSettle();
}

bool _confirmarHabilitado(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirmar cambio'),
        )
        .onPressed !=
    null;

void main() {
  testWidgets('sin elegir producto nuevo no se puede confirmar', (
    tester,
  ) async {
    await _abrir(tester, nuevo: _vainilla);
    expect(_confirmarHabilitado(tester), isFalse);
  });

  testWidgets('cambio de sabor al mismo precio: se confirma sin cobrar', (
    tester,
  ) async {
    final g = await _abrir(tester, nuevo: _vainilla);
    await _elegirProducto(tester);

    expect(find.text('Mismo precio'), findsOneWidget);
    expect(find.text('Cobrar en'), findsNothing);
    expect(_confirmarHabilitado(tester), isTrue);

    await tester.tap(find.text('Confirmar cambio'));
    await tester.pumpAndSettle();

    expect(g.resultado, isTrue);
    expect(g.calculo!.diferencia, 0);
    expect(g.medio, isNull);
  });

  testWidgets('a un producto más caro: cobra la diferencia y pide el monto', (
    tester,
  ) async {
    final g = await _abrir(tester, nuevo: _mocha);
    await _elegirProducto(tester);

    expect(find.text('Cobrar la diferencia'), findsOneWidget);
    expect(find.text('\$500'), findsOneWidget);
    // En efectivo hay que ingresar lo recibido antes de confirmar.
    expect(_confirmarHabilitado(tester), isFalse);

    await tester.enterText(
      find.widgetWithText(TextField, 'Monto recibido'),
      '300',
    );
    await tester.pump();
    expect(_confirmarHabilitado(tester), isFalse);

    await tester.enterText(
      find.widgetWithText(TextField, 'Monto recibido'),
      '1.000',
    );
    await tester.pump();
    expect(find.text('Vuelto: \$500'), findsOneWidget);
    expect(_confirmarHabilitado(tester), isTrue);

    await tester.tap(find.text('Confirmar cambio'));
    await tester.pumpAndSettle();

    expect(g.calculo!.diferencia, 500);
    expect(g.medio, MedioDiferencia.efectivo);
    expect(g.recibido, 1000);
  });

  testWidgets('cobrar con tarjeta no pide monto recibido', (tester) async {
    final g = await _abrir(tester, nuevo: _mocha);
    await _elegirProducto(tester);

    await tester.tap(find.text('Tarjeta'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Monto recibido'), findsNothing);
    expect(_confirmarHabilitado(tester), isTrue);

    await tester.tap(find.text('Confirmar cambio'));
    await tester.pumpAndSettle();
    expect(g.medio, MedioDiferencia.tarjeta);
  });

  testWidgets('a un producto más barato: devuelve la diferencia', (
    tester,
  ) async {
    final g = await _abrir(tester, nuevo: _barra);
    await _elegirProducto(tester);

    expect(find.text('Devolver al cliente'), findsOneWidget);
    expect(find.text('\$1.200'), findsOneWidget);
    // Una venta pagada en efectivo solo se devuelve en efectivo.
    expect(find.text('Devolver en'), findsOneWidget);
    expect(find.text('Tarjeta'), findsNothing);
    expect(_confirmarHabilitado(tester), isTrue);

    await tester.tap(find.text('Confirmar cambio'));
    await tester.pumpAndSettle();
    expect(g.calculo!.diferencia, -1200);
    expect(g.medio, MedioDiferencia.efectivo);
  });

  testWidgets('una venta pagada con tarjeta puede devolverse a la tarjeta', (
    tester,
  ) async {
    await _abrir(tester, nuevo: _barra, metodoOriginal: 'tarjeta');
    await _elegirProducto(tester);

    expect(find.text('Tarjeta'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
  });

  testWidgets('una venta a crédito mueve la deuda del cliente', (tester) async {
    final g = await _abrir(tester, nuevo: _mocha, metodoOriginal: 'credito');
    await _elegirProducto(tester);

    expect(find.text('A la deuda del cliente'), findsOneWidget);
    expect(find.textContaining('Se suma a lo que debe María'), findsOneWidget);
    expect(_confirmarHabilitado(tester), isTrue);

    await tester.tap(find.text('Confirmar cambio'));
    await tester.pumpAndSettle();
    expect(g.medio, MedioDiferencia.deuda);
  });

  testWidgets('con varias unidades se elige cuántas cambiar', (tester) async {
    const tres = ItemVenta(
      productoId: 'latte',
      nombre: 'Café latte',
      cantidad: 3,
      precioUnitario: 2000,
      subtotal: 6000,
    );
    final g = await _abrir(tester, nuevo: _mocha, items: const [tres]);
    await _elegirProducto(tester);
    // Con 1 unidad: 2.500 - 2.000 = 500.
    expect(find.text('\$500'), findsOneWidget);

    await tester.tap(find.byTooltip('Más'));
    await tester.pumpAndSettle();
    // Con 2 unidades: 5.000 - 4.000 = 1.000.
    expect(find.text('\$1.000'), findsOneWidget);

    await tester.tap(find.text('Tarjeta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar cambio'));
    await tester.pumpAndSettle();

    expect(g.calculo!.unidades, 2);
    expect(g.calculo!.diferencia, 1000);
  });

  testWidgets('Cancelar cierra sin registrar nada', (tester) async {
    final g = await _abrir(tester, nuevo: _mocha);
    await _elegirProducto(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(g.resultado, isNull);
    expect(g.calculo, isNull);
  });
}
