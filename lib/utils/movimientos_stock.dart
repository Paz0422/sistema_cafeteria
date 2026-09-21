import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum TipoMovimientoStock {
  stockInicial('Stock inicial'),
  ingreso('Ingreso de mercadería'),
  ajuste('Ajuste manual');

  final String etiqueta;
  const TipoMovimientoStock(this.etiqueta);
}

/// Agrega al [batch] el registro de un cambio manual de stock, para que
/// quede junto (y de forma atómica) con la modificación del producto.
///
/// [cantidad] es la diferencia (positiva o negativa). [stockAnterior] es el
/// stock que el equipo veía al hacer el cambio.
void registrarMovimientoStock(
  WriteBatch batch, {
  required String productoId,
  required String productoNombre,
  required String sucursalId,
  required TipoMovimientoStock tipo,
  required int cantidad,
  required int stockAnterior,
  required String usuarioNombre,
}) {
  batch.set(FirebaseFirestore.instance.collection('movimientosStock').doc(), {
    'fecha': FieldValue.serverTimestamp(),
    'productoId': productoId,
    'productoNombre': productoNombre,
    'sucursalId': sucursalId,
    'tipo': tipo.name,
    'cantidad': cantidad,
    'stockAnterior': stockAnterior,
    'stockNuevo': stockAnterior + cantidad,
    'usuarioUid': FirebaseAuth.instance.currentUser?.uid,
    'usuarioNombre': usuarioNombre,
  });
}
