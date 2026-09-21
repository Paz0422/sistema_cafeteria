import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../theme/marca.dart';
import '../utils/formato.dart';
import '../utils/reporte_turno.dart';
import '../widgets/premium.dart';

/// Se muestra al cerrar el turno: vista previa del reporte con botones para
/// imprimirlo o guardarlo como PDF, y "Continuar" para volver al inicio.
class ReporteTurnoScreen extends StatefulWidget {
  final DatosReporteTurno datos;

  /// Se puede reemplazar en pruebas para no depender del motor de impresión.
  final Future<Uint8List> Function(PdfPageFormat formato)? generar;

  const ReporteTurnoScreen({super.key, required this.datos, this.generar});

  @override
  State<ReporteTurnoScreen> createState() => _ReporteTurnoScreenState();
}

class _ReporteTurnoScreenState extends State<ReporteTurnoScreen> {
  Future<Uint8List> _pdf(PdfPageFormat formato) =>
      (widget.generar ??
      (f) => generarPdfReporteTurno(widget.datos, formato: f))(formato);

  String get _nombreArchivo {
    String dos(int n) => n.toString().padLeft(2, '0');
    final c = widget.datos.cierre;
    final sucursal = widget.datos.sucursal.replaceAll(RegExp(r'\s+'), '-');
    return 'cierre-turno-$sucursal-${c.year}${dos(c.month)}${dos(c.day)}-'
        '${dos(c.hour)}${dos(c.minute)}.pdf';
  }

  Future<void> _guardarPdf() async {
    try {
      final bytes = await _pdf(PdfPageFormat.a4);
      await Printing.sharePdf(bytes: bytes, filename: _nombreArchivo);
    } catch (e) {
      _avisarError('No se pudo guardar el PDF: $e');
    }
  }

  Future<void> _imprimir() async {
    try {
      await Printing.layoutPdf(
        onLayout: _pdf,
        name: _nombreArchivo,
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      _avisarError('No se pudo imprimir: $e');
    }
  }

  void _avisarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Vuelve al inicio (el panel del vendedor o del admin), que es la primera
  /// ruta de la app.
  void _continuar() {
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.datos;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Turno cerrado'),
        ),
        body: FondoFusion(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TarjetaFusion(
                  brillo: true,
                  child: Row(
                    children: [
                      const IconoDorado(Icons.check_rounded, tamano: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'El turno se cerró correctamente',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              d.sucursal,
                              style: const TextStyle(
                                color: Marca.textoSuave,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: PdfPreview(
                  build: _pdf,
                  pdfFileName: _nombreArchivo,
                  useActions: false,
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  maxPageWidth: 700,
                  initialPageFormat: PdfPageFormat.a4,
                  scrollViewDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  loadingWidget: const CircularProgressIndicator(),
                  // Si la vista previa no funciona (por ejemplo, sin internet en
                  // la web), se muestran las cifras en pantalla: el turno ya
                  // está cerrado y el reporte se puede imprimir igual.
                  onError: (context, error) => _ResumenEnPantalla(datos: d),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _guardarPdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Guardar PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _imprimir,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Imprimir reporte'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          onPressed: _continuar,
                          child: const Text('Continuar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Las cifras del cierre en pantalla, para cuando no se puede mostrar la vista
/// previa del PDF.
class _ResumenEnPantalla extends StatelessWidget {
  final DatosReporteTurno datos;

  const _ResumenEnPantalla({required this.datos});

  @override
  Widget build(BuildContext context) {
    final r = datos.resumen;
    final dif = datos.diferencia;

    Widget fila(String etiqueta, String valor, {bool fuerte = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                etiqueta,
                style: TextStyle(
                  fontWeight: fuerte ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No se pudo mostrar la vista previa del reporte en este equipo. '
                'Aquí está el resumen; "Imprimir reporte" y "Guardar PDF" '
                'siguen disponibles.',
                style: TextStyle(color: Marca.textoSuave, fontSize: 12),
              ),
            ),
            TarjetaFusion(
              child: Column(
                children: [
                  fila('Ventas', '${r.cantidadVentas}'),
                  fila(
                    'Vendido en efectivo',
                    formatearPesos(r.vendidoEfectivo),
                  ),
                  fila('Vendido con tarjeta', formatearPesos(r.vendidoTarjeta)),
                  fila('Vendido a crédito', formatearPesos(r.vendidoCredito)),
                  const Divider(height: 20),
                  fila('Total vendido', formatearPesos(r.total), fuerte: true),
                  const Divider(height: 20),
                  fila('Monto inicial', formatearPesos(datos.montoInicial)),
                  fila(
                    'Efectivo esperado',
                    formatearPesos(datos.efectivoEsperado),
                  ),
                  fila('Total contado', formatearPesos(datos.totalContado)),
                  const SizedBox(height: 8),
                  Text(
                    dif == 0
                        ? 'Caja cuadrada'
                        : dif > 0
                        ? 'Sobrante: ${formatearPesos(dif)}'
                        : 'Faltante: ${formatearPesos(-dif)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: dif == 0 ? Marca.exito : Marca.peligro,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
