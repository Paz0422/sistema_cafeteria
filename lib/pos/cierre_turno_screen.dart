import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/escritura_offline.dart';
import '../utils/formato.dart';

class _ResumenVentas {
  final int totalVentas;
  final int totalEfectivo;
  final int totalVendidoEfectivo;
  final int totalTarjeta;
  final int totalCredito;

  const _ResumenVentas({
    this.totalVentas = 0,
    this.totalEfectivo = 0,
    this.totalVendidoEfectivo = 0,
    this.totalTarjeta = 0,
    this.totalCredito = 0,
  });

  factory _ResumenVentas.desde(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var totalVentas = 0;
    var totalEfectivo = 0;
    var totalVendidoEfectivo = 0;
    var totalTarjeta = 0;
    var totalCredito = 0;

    for (final doc in docs) {
      final datos = doc.data();
      if (datos['cancelada'] == true) continue;

      final total = (datos['total'] as num?)?.toInt() ?? 0;
      final montoEfectivo = (datos['montoEfectivo'] as num?)?.toInt() ?? 0;
      final metodo = datos['metodoPago'] as String?;

      totalVentas += total;
      totalEfectivo += montoEfectivo;

      // Una venta mixta se reparte: su parte en efectivo suma a "efectivo"
      // y el resto (lo que no fue efectivo) suma a "tarjeta", en vez de
      // llevar una fila propia de "mixto".
      switch (metodo) {
        case 'efectivo':
          totalVendidoEfectivo += total;
        case 'tarjeta':
          totalTarjeta += total;
        case 'mixto':
          totalVendidoEfectivo += montoEfectivo;
          totalTarjeta += total - montoEfectivo;
        case 'credito':
          totalCredito += total;
      }
    }

    return _ResumenVentas(
      totalVentas: totalVentas,
      totalEfectivo: totalEfectivo,
      totalVendidoEfectivo: totalVendidoEfectivo,
      totalTarjeta: totalTarjeta,
      totalCredito: totalCredito,
    );
  }
}

class CierreTurnoScreen extends StatefulWidget {
  final String turnoId;
  final String vendedorNombre;
  final int montoInicial;
  final bool mostrarAppBar;

  final Widget Function() alCerrar;

  const CierreTurnoScreen({
    super.key,
    required this.turnoId,
    required this.vendedorNombre,
    required this.montoInicial,
    required this.alCerrar,
    this.mostrarAppBar = true,
  });

  @override
  State<CierreTurnoScreen> createState() => _CierreTurnoScreenState();
}

class _CierreTurnoScreenState extends State<CierreTurnoScreen> {
  final _billetesController = TextEditingController();
  final _monedasController = TextEditingController();
  bool _guardando = false;

  int get _billetes => desformatearPesos(_billetesController.text);

  int get _monedas => desformatearPesos(_monedasController.text);

  int get _totalContado => _billetes + _monedas;

  Query<Map<String, dynamic>> get _consultaVentas {
    final vendedorUid = FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance
        .collection('ventas')
        .where('turnoId', isEqualTo: widget.turnoId)
        .where('vendedorUid', isEqualTo: vendedorUid);
  }

  Future<void> _cerrarTurno() async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      // Se recalcula con una lectura fresca justo antes de cerrar, para
      // que la última venta hecha un instante antes quede incluida aunque
      // el stream de la pantalla todavía no la haya reflejado.
      final snapshot = await _consultaVentas.get();
      final resumenFinal = _ResumenVentas.desde(snapshot.docs);
      final efectivoEsperado = widget.montoInicial + resumenFinal.totalEfectivo;
      final diferencia = _totalContado - efectivoEsperado;

      await esperarConfirmacion(
        FirebaseFirestore.instance
            .collection('turnos')
            .doc(widget.turnoId)
            .update({
              'estado': 'cerrado',
              'fechaCierre': FieldValue.serverTimestamp(),
              'totalVentas': resumenFinal.totalVentas,
              'totalEfectivoVentas': resumenFinal.totalEfectivo,
              'totalTarjeta': resumenFinal.totalTarjeta,
              'totalCredito': resumenFinal.totalCredito,
              'efectivoEsperado': efectivoEsperado,
              'billetesCierre': _billetes,
              'monedasCierre': _monedas,
              'totalContado': _totalContado,
              'diferencia': diferencia,
            }),
        siFallaDespues: (error) => mensajero.showSnackBar(
          SnackBar(
            content: Text('El cierre de turno no se pudo sincronizar: $error'),
          ),
        ),
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => widget.alCerrar()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cerrar el turno: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _billetesController.dispose();
    _monedasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.mostrarAppBar
          ? AppBar(title: const Text('Cierre de turno'))
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _consultaVentas.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo calcular el resumen del turno:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final resumen = _ResumenVentas.desde(snapshot.data!.docs);
          final efectivoEsperado = widget.montoInicial + resumen.totalEfectivo;
          final diferencia = _totalContado - efectivoEsperado;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _filaResumen('Monto inicial', widget.montoInicial),
                  _filaResumen('Total vendido', resumen.totalVentas),
                  _filaResumen(
                    'Vendido en efectivo',
                    resumen.totalVendidoEfectivo,
                  ),
                  _filaResumen('Vendido con tarjeta', resumen.totalTarjeta),
                  _filaResumen('Vendido a crédito', resumen.totalCredito),
                  const Divider(height: 32),
                  _filaResumen(
                    'Efectivo esperado en caja',
                    efectivoEsperado,
                    destacado: true,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cuenta el efectivo real en caja',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _billetesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [InputFormatoMiles()],
                    decoration: const InputDecoration(
                      labelText: 'Total en billetes',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _monedasController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [InputFormatoMiles()],
                    decoration: const InputDecoration(
                      labelText: 'Total en monedas',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const Divider(height: 32),
                  _filaResumen('Total contado', _totalContado),
                  Text(
                    diferencia == 0
                        ? 'Caja cuadrada'
                        : diferencia > 0
                        ? 'Sobrante: ${formatearPesos(diferencia)}'
                        : 'Faltante: ${formatearPesos(-diferencia)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: diferencia == 0 ? Colors.green[700] : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _guardando ? null : _cerrarTurno,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_clock),
                    label: const Text('Cerrar turno'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filaResumen(String etiqueta, int valor, {bool destacado = false}) {
    final estilo = TextStyle(
      fontSize: destacado ? 18 : 15,
      fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: estilo),
          Text(formatearPesos(valor), style: estilo),
        ],
      ),
    );
  }
}
