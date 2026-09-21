import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/utils/formato.dart';

void main() {
  group('formatearPesos', () {
    test('agrupa los miles con punto', () {
      expect(formatearPesos(0), '\$0');
      expect(formatearPesos(7), '\$7');
      expect(formatearPesos(999), '\$999');
      expect(formatearPesos(1000), '\$1.000');
      expect(formatearPesos(12500), '\$12.500');
      expect(formatearPesos(123456), '\$123.456');
      expect(formatearPesos(1234567), '\$1.234.567');
    });

    test('los negativos llevan el signo delante', () {
      expect(formatearPesos(-2500), '-\$2.500');
      expect(formatearPesos(-5), '-\$5');
    });
  });

  group('desformatearPesos', () {
    test('quita puntos, signo de pesos y espacios', () {
      expect(desformatearPesos('1.234'), 1234);
      expect(desformatearPesos('\$ 12.500'), 12500);
      expect(desformatearPesos('1.234.567'), 1234567);
    });

    test('vacío o sin dígitos vale 0', () {
      expect(desformatearPesos(''), 0);
      expect(desformatearPesos('abc'), 0);
      expect(desformatearPesos('\$'), 0);
    });

    test('es la inversa de formatearPesos', () {
      for (final valor in [0, 1, 999, 1000, 45000, 1234567]) {
        expect(desformatearPesos(formatearPesos(valor)), valor);
      }
    });
  });

  group('InputFormatoMiles', () {
    final formateador = InputFormatoMiles();

    String formatear(String texto) => formateador
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: texto))
        .text;

    test('formatea mientras se escribe', () {
      expect(formatear('5'), '5');
      expect(formatear('1234'), '1.234');
      expect(formatear('1234567'), '1.234.567');
    });

    test('descarta lo que no sea un dígito', () {
      expect(formatear('12a3b'), '123');
      expect(formatear('\$1.000'), '1.000');
    });

    test('vacío queda vacío', () {
      expect(formatear(''), '');
      expect(formatear('abc'), '');
    });
  });
}
