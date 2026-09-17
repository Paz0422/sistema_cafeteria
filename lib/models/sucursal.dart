import 'package:cloud_firestore/cloud_firestore.dart';

class Sucursal {
  final String id;
  final String nombre;
  final String direccion;
  final String? grupoClientesId;

  const Sucursal({
    required this.id,
    required this.nombre,
    this.direccion = '',
    this.grupoClientesId,
  });

  /// El grupo de clientes al que pertenece esta sucursal. Si nunca se
  /// vinculó con otra, su grupo es simplemente su propio id (clientes
  /// propios, sin compartir con nadie).
  String get grupoClientes =>
      (grupoClientesId == null || grupoClientesId!.isEmpty)
      ? id
      : grupoClientesId!;

  factory Sucursal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final datos = doc.data()!;
    return Sucursal(
      id: doc.id,
      nombre: datos['nombre'] as String,
      direccion: datos['direccion'] as String? ?? '',
      grupoClientesId: datos['grupoClientesId'] as String?,
    );
  }
}
