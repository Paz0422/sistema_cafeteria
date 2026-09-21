import '../models/producto.dart';

/// Minúsculas y sin tildes, para que "cafe" encuentre "Café" y "ñ" no estorbe.
String normalizarParaBuscar(String texto) {
  const con = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sin = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final c in texto.toLowerCase().split('')) {
    final i = con.indexOf(c);
    buffer.write(i == -1 ? c : sin[i]);
  }
  return buffer.toString();
}

/// Productos cuyo nombre contiene todas las palabras de [consulta], sin
/// importar el orden ni las tildes. Primero los que empiezan con lo escrito,
/// después el resto por orden alfabético.
List<Producto> buscarProductosPorNombre(
  Iterable<Producto> productos,
  String consulta, {
  int maximo = 8,
}) {
  final palabras = normalizarParaBuscar(
    consulta,
  ).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (palabras.isEmpty) return const [];

  final completa = palabras.join(' ');
  final resultados = <(Producto, String)>[];
  for (final producto in productos) {
    final nombre = normalizarParaBuscar(producto.nombre);
    if (palabras.every(nombre.contains)) resultados.add((producto, nombre));
  }

  resultados.sort((a, b) {
    final empiezaA = a.$2.startsWith(completa) ? 0 : 1;
    final empiezaB = b.$2.startsWith(completa) ? 0 : 1;
    if (empiezaA != empiezaB) return empiezaA.compareTo(empiezaB);
    return a.$2.compareTo(b.$2);
  });
  return [for (final r in resultados.take(maximo)) r.$1];
}
