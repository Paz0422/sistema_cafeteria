import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sucursal.dart';
import 'apertura_caja_screen.dart';
import '../widgets/logo_fusion.dart';

/// Elige en qué sucursal se va a trabajar este turno y abre la caja ahí.
/// La usan tanto un vendedor normal (siempre puede elegir cualquier
/// sucursal, porque un mismo cajero puede trabajar en distintos locales
/// según el día) como el admin desde su "Panel vendedor".
class SelectorSucursalApertura extends StatefulWidget {
  final String nombreVendedor;
  final bool esAdmin;
  final String descripcion;
  final String textoBoton;

  const SelectorSucursalApertura({
    super.key,
    required this.nombreVendedor,
    this.esAdmin = false,
    this.descripcion = 'Elige en qué sucursal vas a trabajar hoy.',
    this.textoBoton = 'Abrir turno',
  });

  @override
  State<SelectorSucursalApertura> createState() =>
      _SelectorSucursalAperturaState();
}

class _SelectorSucursalAperturaState extends State<SelectorSucursalApertura> {
  String? _sucursalId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('sucursales').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sucursales = snapshot.data!.docs.map(Sucursal.fromDoc).toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre));

        if (sucursales.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavía no hay ninguna sucursal creada. Pídele a un '
                'administrador que cree una antes de abrir turno.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final sucursalId =
            (_sucursalId != null && sucursales.any((s) => s.id == _sucursalId))
            ? _sucursalId!
            : sucursales.first.id;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MascotaFusion(tamano: 130),
                      const SizedBox(height: 16),
                      Text(widget.descripcion, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        initialValue: sucursalId,
                        decoration: const InputDecoration(
                          labelText: 'Sucursal',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final sucursal in sucursales)
                            DropdownMenuItem(
                              value: sucursal.id,
                              child: Text(sucursal.nombre),
                            ),
                        ],
                        onChanged: (valor) =>
                            setState(() => _sucursalId = valor),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AperturaCajaScreen(
                                  vendedorNombre: widget.nombreVendedor,
                                  sucursalId: sucursalId,
                                  esAdmin: widget.esAdmin,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login),
                          label: Text(widget.textoBoton),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
