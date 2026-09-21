import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:cafeteria_sistema/constants.dart';
import 'package:cafeteria_sistema/utils/acceso.dart';

void main() {
  test('normalizarUsuario quita espacios y pasa a minúsculas', () {
    expect(normalizarUsuario('  Paz '), 'paz');
  });

  group('correoDeAcceso', () {
    test('la primera generación es usuario@dominio', () {
      expect(correoDeAcceso('paz'), 'paz$dominioInterno');
      expect(correoDeAcceso('paz', generacion: 1), 'paz$dominioInterno');
    });

    test('las siguientes generaciones agregan +gN', () {
      expect(correoDeAcceso('paz', generacion: 2), 'paz+g2$dominioInterno');
      expect(correoDeAcceso('paz', generacion: 7), 'paz+g7$dominioInterno');
    });
  });

  test('idAcceso no deja "/" sin codificar', () {
    expect(idAcceso('paz'), 'paz');
    expect(idAcceso('a/b'), isNot(contains('/')));
  });

  group('generarContrasenaTemporal', () {
    test('tiene el largo pedido y solo letras y números legibles', () {
      final clave = generarContrasenaTemporal(azar: Random(1));
      expect(clave.length, 8);
      expect(clave, matches(RegExp(r'^[a-zA-Z2-9]+$')));
      expect(clave, isNot(matches(RegExp(r'[0OolIi1]'))));
    });

    test('dos contraseñas seguidas no son iguales', () {
      expect(generarContrasenaTemporal(), isNot(generarContrasenaTemporal()));
    });
  });
}
