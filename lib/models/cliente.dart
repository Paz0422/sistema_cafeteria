import 'package:cloud_firestore/cloud_firestore.dart';

class Cliente {
  final String id;
  final String grupoClientesId;
  final String nombre;
  final String telefono;
  final String direccion;
  final int limiteCredito;
  final int deuda;

  const Cliente({
    required this.id,
    required this.grupoClientesId,
    required this.nombre,
    this.telefono = '',
    this.direccion = '',
    this.limiteCredito = 0,
    this.deuda = 0,
  });

  int get creditoDisponible => limiteCredito - deuda;

  factory Cliente.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final datos = doc.data()!;
    return Cliente(
      id: doc.id,
      grupoClientesId: datos['grupoClientesId'] as String? ?? '',
      nombre: datos['nombre'] as String,
      telefono: datos['telefono'] as String? ?? '',
      direccion: datos['direccion'] as String? ?? '',
      limiteCredito: (datos['limiteCredito'] as num?)?.toInt() ?? 0,
      deuda: (datos['deuda'] as num?)?.toInt() ?? 0,
    );
  }
}
