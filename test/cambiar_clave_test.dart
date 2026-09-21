import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/auth/cambiar_clave_screen.dart';
import 'package:cafeteria_sistema/theme/marca.dart';

Future<void> _abrir(
  WidgetTester tester,
  Future<void> Function(String) guardar,
) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: temaFusion(),
      home: CambiarClaveScreen(uid: 'u1', guardar: guardar),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('una contraseña corta no se guarda', (tester) async {
    var llamadas = 0;
    await _abrir(tester, (_) async => llamadas++);

    await tester.enterText(find.byType(TextField).at(0), '123');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();

    expect(llamadas, 0);
    expect(find.textContaining('al menos 6'), findsOneWidget);
  });

  testWidgets('si no coinciden no se guarda', (tester) async {
    var llamadas = 0;
    await _abrir(tester, (_) async => llamadas++);

    await tester.enterText(find.byType(TextField).at(0), 'clave-nueva');
    await tester.enterText(find.byType(TextField).at(1), 'clave-otra');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();

    expect(llamadas, 0);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('con datos válidos guarda la contraseña nueva', (tester) async {
    String? guardada;
    await _abrir(tester, (nueva) async => guardada = nueva);

    await tester.enterText(find.byType(TextField).at(0), 'clave-nueva');
    await tester.enterText(find.byType(TextField).at(1), 'clave-nueva');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();

    expect(guardada, 'clave-nueva');
  });
}
