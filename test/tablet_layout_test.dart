import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/auth/login_screen.dart';
import 'package:cafeteria_sistema/pos/dialogo_pago.dart';
import 'package:cafeteria_sistema/register_screen.dart';
import 'package:cafeteria_sistema/theme/marca.dart';

// Tamaños lógicos de tablets comunes (ancho x alto en píxeles lógicos).
const _tamanos = {
  'tablet 10" vertical (768x1024)': Size(768, 1024),
  'tablet 10" horizontal (1024x768)': Size(1024, 768),
  'tablet 8" horizontal (1280x800)': Size(1280, 800),
};

// Alto que ocupa el teclado en pantalla de una tablet en horizontal.
const _alturaTeclado = 320.0;

// Pantallas de acceso: además de tablets, celular y PC (el panel con la
// mascota solo aparece desde 900 px de ancho).
const _tamanosAcceso = {
  'celular (390x844)': Size(390, 844),
  'tablet vertical (768x1024)': Size(768, 1024),
  'tablet horizontal (1024x768)': Size(1024, 768),
  'PC (1440x900)': Size(1440, 900),
};

void _pruebasAcceso(String nombre, Widget Function() pantalla) {
  for (final entrada in _tamanosAcceso.entries) {
    testWidgets('$nombre sin desbordes en ${entrada.key}', (tester) async {
      tester.view.physicalSize = entrada.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: temaFusion(), home: pantalla()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('$nombre con teclado abierto en ${entrada.key}', (
      tester,
    ) async {
      tester.view.physicalSize = entrada.value;
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: _alturaTeclado);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: temaFusion(), home: pantalla()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}

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

  _pruebasAcceso('Login', () => const LoginScreen());
  _pruebasAcceso('Registro', () => const RegisterScreen());
}
