import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/cuentas_guardadas.dart';
import '../utils/escritura_offline.dart';
import '../utils/formato.dart';
import '../utils/reporte_turno.dart';
import '../utils/resumen_ventas.dart';
import '../theme/marca.dart';
import 'reporte_turno_screen.dart';

class CierreTurnoScreen extends StatefulWidget {
  final String turnoId;
  final String vendedorNombre;
  final int montoInicial;
  final bool mostrarAppBar;

  const CierreTurnoScreen({
    super.key,
    required this.turnoId,
    required this.vendedorNombre,
    required this.montoInicial,
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

  /// Junta lo necesario para el reporte impreso. Si no se puede (por ejemplo
  /// sin internet y sin datos guardados), devuelve null: el reporte nunca debe
  /// impedir cerrar el turno.
  Future<DatosReporteTurno?> _datosReporte(
    Iterable<Map<String, dynamic>> ventas,
    DateTime cierre,
  ) async {
    const espera = Duration(seconds: 3);
    try {
      final db = FirebaseFirestore.instance;
      final turno =
          (await db
                  .collection('turnos')
                  .doc(widget.turnoId)
                  .get()
                  .timeout(espera))
              .data();

      var sucursal = 'Sucursal';
      final sucursalId = turno?['sucursalId'] as String?;
      if (sucursalId != null) {
        final doc = await db
            .collection('sucursales')
            .doc(sucursalId)
            .get()
            .timeout(espera);
        sucursal = doc.data()?['nombre'] as String? ?? sucursal;
      }

      return armarDatosReporteTurno(
        sucursal: sucursal,
        vendedor: widget.vendedorNombre,
        apertura: (turno?['fechaApertura'] as Timestamp?)?.toDate(),
        cierre: cierre,
        montoInicial: widget.montoInicial,
        ventas: ventas,
        billetesContados: _billetes,
        monedasContadas: _monedas,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cerrarTurno() async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      // Se recalcula con una lectura fresca justo antes de cerrar, para
      // que la última venta hecha un instante antes quede incluida aunque
      // el stream de la pantalla todavía no la haya reflejado.
      final snapshot = await _consultaVentas.get();
      final ventasDelTurno = snapshot.docs.map((doc) => doc.data()).toList();
      final resumenFinal = resumirVentas(ventasDelTurno);
      final cierre = DateTime.now();
      final reporte = await _datosReporte(ventasDelTurno, cierre);
      final efectivoEsperado =
          widget.montoInicial + resumenFinal.efectivoEnCaja;
      final diferencia = _totalContado - efectivoEsperado;

      await esperarConfirmacion(
        FirebaseFirestore.instance
            .collection('turnos')
            .doc(widget.turnoId)
            .update({
              'estado': 'cerrado',
              'fechaCierre': FieldValue.serverTimestamp(),
              'totalVentas': resumenFinal.total,
              'totalEfectivoVentas': resumenFinal.efectivoEnCaja,
              'totalTarjeta': resumenFinal.vendidoTarjeta,
              'totalCredito': resumenFinal.vendidoCredito,
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

      // Con el turno cerrado no queda nada que recuperar.
      await borrarCuentas(widget.turnoId).catchError((_) {});

      if (mounted) {
        // Se vuelve al inicio dejando la primera ruta (la que decide el panel
        // según la sesión): si se la reemplazara, cerrar sesión después no
        // llevaría al login. Con el turno cerrado se muestra antes el reporte
        // para imprimir.
        final navegador = Navigator.of(context);
        if (reporte == null) {
          navegador.popUntil((ruta) => ruta.isFirst);
        } else {
          navegador.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => ReporteTurnoScreen(datos: reporte),
            ),
            (ruta) => ruta.isFirst,
          );
        }
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
                  style: const TextStyle(color: Marca.peligro),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final resumen = resumirVentas(
            snapshot.data!.docs.map((doc) => doc.data()),
          );
          final efectivoEsperado = widget.montoInicial + resumen.efectivoEnCaja;
          final diferencia = _totalContado - efectivoEsperado;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _filaResumen('Monto inicial', widget.montoInicial),
                  _filaResumen('Total vendido', resumen.total),
                  _filaResumen('Vendido en efectivo', resumen.vendidoEfectivo),
                  _filaResumen('Vendido con tarjeta', resumen.vendidoTarjeta),
                  _filaResumen('Vendido a crédito', resumen.vendidoCredito),
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
                      color: diferencia == 0 ? Marca.exito : Marca.peligro,
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
