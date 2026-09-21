import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cambio_venta.dart';
import 'escritura_offline.dart';

/// El producto que se lleva no alcanza en stock.
class StockInsuficienteEnCambio implements Exception {
  final String nombre;
  final int disponible;

  StockInsuficienteEnCambio(this.nombre, this.disponible);
}

/// A un cliente con crédito la diferencia le supera el límite.
class LimiteCreditoEnCambio implements Exception {
  final String nombre;
  final int disponible;

  LimiteCreditoEnCambio(this.nombre, this.disponible);
}

int _stockEn(Map<String, dynamic>? producto, String sucursalId) {
  final porSucursal = producto?['stockPorSucursal'] as Map<String, dynamic>?;
  return (porSucursal?[sucursalId] as num?)?.toInt() ?? 0;
}

/// Guarda un cambio de producto: devuelve el stock del producto que vuelve,
/// descuenta el que se lleva y registra la diferencia como un movimiento
/// nuevo del turno (la venta original no se modifica).
///
/// Todo va en un solo lote: o queda completo o no cambia nada. Con el lote
/// también funciona sin internet (se envía solo al volver la conexión).
/// Devuelve `true` si el servidor lo confirmó a tiempo.
Future<bool> registrarCambio({
  required CalculoCambio calculo,
  required MedioDiferencia? medio,
  required int efectivoRecibido,
  required String ventaOriginalId,
  required String turnoId,
  required String sucursalId,
  required String vendedorNombre,
  String? clienteId,
  String? clienteNombre,
  void Function(Object error)? siFallaDespues,
}) async {
  final db = FirebaseFirestore.instance;
  final refViejo = db
      .collection('productos')
      .doc(calculo.itemDevuelto.productoId);
  final refNuevo = db.collection('productos').doc(calculo.productoNuevo.id);

  // Lecturas frescas antes de escribir, para validar con el stock real.
  final viejo = (await refViejo.get()).data();
  final nuevo = (await refNuevo.get()).data();

  final batch = db.batch();

  if (viejo != null && (viejo['controlaStock'] as bool? ?? false)) {
    batch.update(refViejo, {
      'stockPorSucursal.$sucursalId': FieldValue.increment(calculo.unidades),
    });
  }

  if (nuevo != null && (nuevo['controlaStock'] as bool? ?? false)) {
    final disponible = _stockEn(nuevo, sucursalId);
    if (disponible < calculo.unidades) {
      throw StockInsuficienteEnCambio(calculo.productoNuevo.nombre, disponible);
    }
    batch.update(refNuevo, {
      'stockPorSucursal.$sucursalId': FieldValue.increment(-calculo.unidades),
    });
  }

  final diferencia = calculo.diferencia;
  if (medio == MedioDiferencia.deuda && clienteId != null && diferencia != 0) {
    final refCliente = db.collection('clientes').doc(clienteId);
    final cliente = (await refCliente.get()).data();
    final deuda = (cliente?['deuda'] as num?)?.toInt() ?? 0;
    final limite = (cliente?['limiteCredito'] as num?)?.toInt() ?? 0;
    final nuevaDeuda = deuda + diferencia;
    if (diferencia > 0 && nuevaDeuda > limite) {
      throw LimiteCreditoEnCambio(
        clienteNombre ?? 'El cliente',
        limite - deuda,
      );
    }
    batch.update(refCliente, {'deuda': nuevaDeuda < 0 ? 0 : nuevaDeuda});
  }

  batch.set(db.collection('ventas').doc(), {
    ...datosDeCambio(
      calculo: calculo,
      medio: medio,
      efectivoRecibido: efectivoRecibido,
      ventaOriginalId: ventaOriginalId,
      turnoId: turnoId,
      sucursalId: sucursalId,
      clienteId: clienteId,
      clienteNombre: clienteNombre,
    ),
    'fecha': FieldValue.serverTimestamp(),
    'vendedorUid': FirebaseAuth.instance.currentUser?.uid,
    'vendedorNombre': vendedorNombre,
  });

  return esperarConfirmacion(batch.commit(), siFallaDespues: siFallaDespues);
}
