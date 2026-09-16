import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/main.dart';

void main() {
  testWidgets('MyApp se construye sin lanzar excepciones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
  });
}
