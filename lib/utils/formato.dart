import 'package:flutter/services.dart';

String _agruparMiles(String digitos) {
  final buffer = StringBuffer();

  for (var i = 0; i < digitos.length; i++) {
    final posicionDesdeElFinal = digitos.length - i;
    buffer.write(digitos[i]);
    if (posicionDesdeElFinal > 1 && posicionDesdeElFinal % 3 == 1) {
      buffer.write('.');
    }
  }

  return buffer.toString();
}

String formatearPesos(int valor) {
  final signo = valor < 0 ? '-' : '';
  return '$signo\$${_agruparMiles(valor.abs().toString())}';
}

int desformatearPesos(String texto) {
  final soloDigitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
  return soloDigitos.isEmpty ? 0 : int.parse(soloDigitos);
}

class InputFormatoMiles extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue valorAnterior,
    TextEditingValue valorNuevo,
  ) {
    final soloDigitos = valorNuevo.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (soloDigitos.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final formateado = _agruparMiles(soloDigitos);
    return TextEditingValue(
      text: formateado,
      selection: TextSelection.collapsed(offset: formateado.length),
    );
  }
}
