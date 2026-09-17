import 'package:cloud_firestore/cloud_firestore.dart';

class Producto {
  final String id;
  final String codigoBarras;
  final String nombre;
  final int precio;
  final int promoCantidad;
  final int promoPrecioPack;
  final bool controlaStock;
  final Map<String, int> stockPorSucursal;

  const Producto({
    required this.id,
    required this.codigoBarras,
    required this.nombre,
    required this.precio,
    this.promoCantidad = 0,
    this.promoPrecioPack = 0,
    this.controlaStock = true,
    this.stockPorSucursal = const {},
  });

  bool get tienePromo =>
      promoCantidad > 0 &&
      promoPrecioPack > 0 &&
      promoPrecioPack < promoCantidad * precio;

  int stockEn(String sucursalId) => stockPorSucursal[sucursalId] ?? 0;

  factory Producto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final datos = doc.data()!;
    final stockCrudo = datos['stockPorSucursal'] as Map<String, dynamic>?;

    return Producto(
      id: doc.id,
      codigoBarras: datos['codigoBarras'] as String,
      nombre: datos['nombre'] as String,
      precio: (datos['precio'] as num).toInt(),
      promoCantidad: (datos['promoCantidad'] as num?)?.toInt() ?? 0,
      promoPrecioPack: (datos['promoPrecioPack'] as num?)?.toInt() ?? 0,
      controlaStock: datos['controlaStock'] as bool? ?? true,
      stockPorSucursal: stockCrudo == null
          ? const {}
          : stockCrudo.map(
              (sucursalId, valor) =>
                  MapEntry(sucursalId, (valor as num).toInt()),
            ),
    );
  }
}
