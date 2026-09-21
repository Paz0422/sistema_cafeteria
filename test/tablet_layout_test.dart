import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/pos/dialogo_pago.dart';

// Tamaños lógicos de tablets comunes (ancho x alto en píxeles lógicos).
const _tamanos = {
  'tablet 10" vertical (768x1024)': Size(768, 1024),
  'tablet 10" horizontal (1024x768)': Size(1024, 768),
  'tablet 8" horizontal (1280x800)': Size(1280, 800),
};

// Alto que ocupa el teclado en pantalla de una tablet en horizontal.
const _alturaTeclado = 320.0;

Future<void> _abrirDialogoPago(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) =>
                  const DialogoPago(total: 12500, grupoClientesId: 'grupo'),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  for (final entrada in _tamanos.entries) {
    testWidgets('Diálogo de cobro sin desbordes en ${entrada.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entrada.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _abrirDialogoPago(tester);

      // Se recorre cada método de pago: cada uno muestra campos distintos.
      for (final metodo in ['Tarjeta', 'Mixto', 'Crédito', 'Efectivo']) {
        await tester.tap(find.text(metodo));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('Diálogo de cobro con teclado abierto en ${entrada.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entrada.value;
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: _alturaTeclado);
      addTearDown(tester.view.reset);

      await _abrirDialogoPago(tester);
      await tester.tap(find.text('Mixto'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
