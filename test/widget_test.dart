import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/main.dart';

void main() {
  // AuthGate (la pantalla real de inicio) necesita Firebase inicializado, que
  // no existe en las pruebas; por eso se reemplaza por una pantalla simple.
  // Lo que se comprueba es la configuración de la app: tema, idioma y textos
  // en español (los usa, por ejemplo, el selector de fechas de Estadísticas).
  testWidgets('MyApp se construye y queda configurada en español', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(home: Scaffold(body: Text('inicio'))));

    expect(find.text('inicio'), findsOneWidget);

    final contexto = tester.element(find.text('inicio'));
    expect(Localizations.localeOf(contexto).languageCode, 'es');
    expect(MaterialLocalizations.of(contexto).cancelButtonLabel, 'Cancelar');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Cafetería Fusión',
    );
  });
}
