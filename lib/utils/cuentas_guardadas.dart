import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cuenta_abierta.dart';
import '../models/item_carrito.dart';
import '../models/producto.dart';

/// Las cuentas (carritos) abiertas de un turno tal como se guardaron.
class CuentasGuardadas {
  final List<CuentaAbierta> cuentas;
  final int indiceActivo;

  /// Cuántas cuentas se han abierto en el turno: da el número de la próxima
  /// ("Cuenta 4"), aunque las anteriores ya se hayan cerrado.
  final int contador;

  const CuentasGuardadas({
    required this.cuentas,
    required this.indiceActivo,
    required this.contador,
  });
}

String _clave(String turnoId) => 'cuentas_turno_$turnoId';

Map<String, dynamic> _productoAJson(Producto p) => {
  'id': p.id,
  'codigoBarras': p.codigoBarras,
  'nombre': p.nombre,
  'precio': p.precio,
  'promoCantidad': p.promoCantidad,
  'promoPrecioPack': p.promoPrecioPack,
  'controlaStock': p.controlaStock,
};

Producto _productoDeJson(Map<String, dynamic> j) => Producto(
  id: j['id'] as String,
  codigoBarras: j['codigoBarras'] as String? ?? '',
  nombre: j['nombre'] as String? ?? '',
  precio: (j['precio'] as num).toInt(),
  promoCantidad: (j['promoCantidad'] as num?)?.toInt() ?? 0,
  promoPrecioPack: (j['promoPrecioPack'] as num?)?.toInt() ?? 0,
  controlaStock: j['controlaStock'] as bool? ?? true,
);

/// Convierte las cuentas a un JSON simple. El stock no se guarda: al volver se
/// lee el que tenga el catálogo en ese momento.
Map<String, dynamic> cuentasAJson({
  required List<CuentaAbierta> cuentas,
  required int indiceActivo,
  required int contador,
}) => {
  'indiceActivo': indiceActivo,
  'contador': contador,
  'cuentas': [
    for (final c in cuentas)
      {
        'id': c.id,
        'nombre': c.nombre,
        'items': [
          for (final i in c.carrito)
            {'producto': _productoAJson(i.producto), 'cantidad': i.cantidad},
        ],
      },
  ],
};

/// Lo contrario de [cuentasAJson]. Devuelve null si los datos no sirven.
CuentasGuardadas? cuentasDeJson(Map<String, dynamic> json) {
  try {
    final cuentas = [
      for (final c in json['cuentas'] as List)
        CuentaAbierta(
          id: c['id'] as String,
          nombre: c['nombre'] as String,
          carrito: [
            for (final i in c['items'] as List)
              ItemCarrito(
                producto: _productoDeJson(
                  Map<String, dynamic>.from(i['producto'] as Map),
                ),
                cantidad: (i['cantidad'] as num).toInt(),
              ),
          ],
        ),
    ];
    if (cuentas.isEmpty) return null;

    final indice = (json['indiceActivo'] as num?)?.toInt() ?? 0;
    return CuentasGuardadas(
      cuentas: cuentas,
      indiceActivo: indice.clamp(0, cuentas.length - 1),
      contador: (json['contador'] as num?)?.toInt() ?? cuentas.length,
    );
  } catch (_) {
    return null;
  }
}

/// True si no hay nada que valga la pena guardar: una sola cuenta vacía.
bool _sinContenido(List<CuentaAbierta> cuentas) =>
    cuentas.length == 1 && cuentas.first.carrito.isEmpty;

/// Guarda en este equipo las cuentas abiertas del turno, para poder seguir
/// después de un corte de luz o de cerrar la página por error.
Future<void> guardarCuentas(
  String turnoId, {
  required List<CuentaAbierta> cuentas,
  required int indiceActivo,
  required int contador,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (_sinContenido(cuentas)) {
    await prefs.remove(_clave(turnoId));
    return;
  }
  await prefs.setString(
    _clave(turnoId),
    jsonEncode(
      cuentasAJson(
        cuentas: cuentas,
        indiceActivo: indiceActivo,
        contador: contador,
      ),
    ),
  );
}

Future<CuentasGuardadas?> cargarCuentas(String turnoId) async {
  final prefs = await SharedPreferences.getInstance();
  final texto = prefs.getString(_clave(turnoId));
  if (texto == null) return null;
  try {
    return cuentasDeJson(jsonDecode(texto) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// Se llama al cerrar el turno: ya no hay nada que recuperar.
Future<void> borrarCuentas(String turnoId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_clave(turnoId));
}
