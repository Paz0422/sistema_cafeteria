import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../theme/marca.dart';
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
    final bytes = await _pdf(PdfPageFormat.a4);
    await Printing.sharePdf(bytes: bytes, filename: _nombreArchivo);
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
                  onError: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudo generar el reporte.\n$error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Marca.peligro),
                      ),
                    ),
                  ),
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
                          onPressed: () => Printing.layoutPdf(
                            onLayout: _pdf,
                            name: _nombreArchivo,
                            format: PdfPageFormat.a4,
                          ),
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
