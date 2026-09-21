import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'formato.dart';
import 'resumen_ventas.dart';

/// Una venta del turno tal como sale en el detalle del reporte.
class VentaReporte {
  final DateTime hora;
  final String metodo;
  final String cliente;
  final int total;
  final bool anulada;

  const VentaReporte({
    required this.hora,
    required this.metodo,
    required this.cliente,
    required this.total,
    required this.anulada,
  });
}

/// Unidades y monto vendidos de un producto durante el turno.
class ProductoReporte {
  final String nombre;
  final int unidades;
  final int monto;

  const ProductoReporte({
    required this.nombre,
    required this.unidades,
    required this.monto,
  });
}

/// Todo lo que lleva el reporte impreso del cierre de turno.
class DatosReporteTurno {
  final String sucursal;
  final String vendedor;
  final DateTime? apertura;
  final DateTime cierre;

  final int montoInicial;
  final ResumenVentas resumen;
  final List<ProductoReporte> productos;
  final List<VentaReporte> ventas;

  final int billetesContados;
  final int monedasContadas;

  const DatosReporteTurno({
    required this.sucursal,
    required this.vendedor,
    required this.apertura,
    required this.cierre,
    required this.montoInicial,
    required this.resumen,
    required this.productos,
    required this.ventas,
    required this.billetesContados,
    required this.monedasContadas,
  });

  int get efectivoEsperado => montoInicial + resumen.efectivoEnCaja;
  int get totalContado => billetesContados + monedasContadas;
  int get diferencia => totalContado - efectivoEsperado;
  int get anuladas => ventas.where((v) => v.anulada).length;
}

/// Arma los datos del reporte a partir de las ventas del turno (los datos de
/// cada documento de `ventas`). Las ventas anuladas se listan aparte y no
/// suman a ningún total, igual que en el resto del sistema.
DatosReporteTurno armarDatosReporteTurno({
  required String sucursal,
  required String vendedor,
  required DateTime? apertura,
  required DateTime cierre,
  required int montoInicial,
  required Iterable<Map<String, dynamic>> ventas,
  required int billetesContados,
  required int monedasContadas,
}) {
  final lista = ventas.toList();

  final unidades = <String, int>{};
  final montos = <String, int>{};
  final detalle = <VentaReporte>[];

  for (final datos in lista) {
    final anulada = datos['cancelada'] == true;
    final fecha = (datos['fecha'] as Timestamp?)?.toDate() ?? cierre;
    detalle.add(
      VentaReporte(
        hora: fecha,
        metodo: datos['esCambio'] == true
            ? 'Cambio (${_etiquetaMetodo(datos['metodoPago'] as String?).toLowerCase()})'
            : _etiquetaMetodo(datos['metodoPago'] as String?),
        cliente: (datos['clienteNombre'] as String?) ?? '',
        total: (datos['total'] as num?)?.toInt() ?? 0,
        anulada: anulada,
      ),
    );
    if (anulada) continue;

    for (final item in (datos['items'] as List? ?? const [])) {
      final nombre = item['nombre'] as String? ?? '';
      unidades[nombre] =
          (unidades[nombre] ?? 0) + ((item['cantidad'] as num?)?.toInt() ?? 0);
      montos[nombre] =
          (montos[nombre] ?? 0) + ((item['subtotal'] as num?)?.toInt() ?? 0);
    }
  }

  detalle.sort((a, b) => a.hora.compareTo(b.hora));
  final productos = [
    for (final e in unidades.entries)
      ProductoReporte(
        nombre: e.key,
        unidades: e.value,
        monto: montos[e.key] ?? 0,
      ),
  ]..sort((a, b) => b.unidades.compareTo(a.unidades));

  return DatosReporteTurno(
    sucursal: sucursal,
    vendedor: vendedor,
    apertura: apertura,
    cierre: cierre,
    montoInicial: montoInicial,
    resumen: resumirVentas(lista),
    productos: productos,
    ventas: detalle,
    billetesContados: billetesContados,
    monedasContadas: monedasContadas,
  );
}

String _etiquetaMetodo(String? metodo) => switch (metodo) {
  'efectivo' => 'Efectivo',
  'tarjeta' => 'Tarjeta',
  'mixto' => 'Mixto',
  'credito' => 'Crédito',
  _ => '-',
};

String _dos(int n) => n.toString().padLeft(2, '0');

String _fechaHora(DateTime f) =>
    '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';

String _hora(DateTime f) => '${_dos(f.hour)}:${_dos(f.minute)}';

String _duracion(DateTime desde, DateTime hasta) {
  final d = hasta.difference(desde);
  if (d.isNegative) return '';
  return '${d.inHours} h ${_dos(d.inMinutes.remainder(60))} min';
}

const _dorado = PdfColor.fromInt(0xFFD99A1F);
const _oscuro = PdfColor.fromInt(0xFF1B1B1B);
const _gris = PdfColor.fromInt(0xFF6B655C);
const _lineas = PdfColor.fromInt(0xFFD9D2C5);
const _fondoFila = PdfColor.fromInt(0xFFF6F3EE);

/// Genera el PDF del reporte de cierre de turno (tamaño carta/A4), listo para
/// imprimir o guardar.
Future<Uint8List> generarPdfReporteTurno(
  DatosReporteTurno d, {
  PdfPageFormat formato = PdfPageFormat.a4,
}) async {
  // Poppins va dentro de la app; con ella se ven bien las tildes y la ñ.
  final tema = pw.ThemeData.withFont(
    base: pw.Font.ttf(
      await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
    ),
    bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Bold.ttf')),
    italic: pw.Font.ttf(
      await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
    ),
    boldItalic: pw.Font.ttf(
      await rootBundle.load('assets/fonts/Poppins-Bold.ttf'),
    ),
  );

  // El logo no va en el repositorio: si no está, el reporte sale sin él.
  pw.MemoryImage? logo;
  try {
    final bytes = await rootBundle.load('assets/images/logo.png');
    logo = pw.MemoryImage(bytes.buffer.asUint8List());
  } catch (_) {
    logo = null;
  }

  final doc = pw.Document(
    title: 'Cierre de turno - ${d.sucursal}',
    author: 'Cafetería Fusión',
  );

  pw.Widget titulo(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
    child: pw.Row(
      children: [
        pw.Container(width: 4, height: 14, color: _dorado),
        pw.SizedBox(width: 8),
        pw.Text(
          texto,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: _oscuro,
          ),
        ),
      ],
    ),
  );

  pw.Widget fila(
    String etiqueta,
    String valor, {
    bool fuerte = false,
    PdfColor color = _oscuro,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _lineas, width: 0.5)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          etiqueta,
          style: pw.TextStyle(
            fontSize: fuerte ? 11 : 10,
            fontWeight: fuerte ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
        pw.Text(
          valor,
          style: pw.TextStyle(
            fontSize: fuerte ? 11 : 10,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );

  pw.Widget tabla(
    List<String> encabezados,
    List<List<String>> filas, {
    required Map<int, pw.TableColumnWidth> anchos,
    Set<int> derecha = const {},
    Set<int> filasTenues = const {},
  }) {
    pw.Widget celda(
      String t,
      int col, {
      bool encabezado = false,
      bool tenue = false,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        t,
        textAlign: derecha.contains(col)
            ? pw.TextAlign.right
            : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: encabezado ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: tenue ? _gris : _oscuro,
          decoration: tenue ? pw.TextDecoration.lineThrough : null,
        ),
      ),
    );

    return pw.Table(
      columnWidths: anchos,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _lineas, width: 0.4),
        bottom: pw.BorderSide(color: _lineas, width: 0.4),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _fondoFila),
          children: [
            for (var i = 0; i < encabezados.length; i++)
              celda(encabezados[i], i, encabezado: true),
          ],
        ),
        for (var r = 0; r < filas.length; r++)
          pw.TableRow(
            children: [
              for (var i = 0; i < filas[r].length; i++)
                celda(filas[r][i], i, tenue: filasTenues.contains(r)),
            ],
          ),
      ],
    );
  }

  final r = d.resumen;
  final dif = d.diferencia;

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: formato,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
        theme: tema,
      ),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                'Cierre de turno · ${d.sucursal} · ${_fechaHora(d.cierre)}',
                style: const pw.TextStyle(fontSize: 8, color: _gris),
              ),
            ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Cafetería Fusión',
            style: const pw.TextStyle(fontSize: 8, color: _gris),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _gris),
          ),
        ],
      ),
      build: (context) => [
        // Encabezado.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[
              pw.Image(logo, width: 54, height: 54),
              pw.SizedBox(width: 14),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Cafetería Fusión',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _oscuro,
                    ),
                  ),
                  pw.Text(
                    'Reporte de cierre de turno',
                    style: const pw.TextStyle(fontSize: 11, color: _gris),
                  ),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _dorado, width: 1),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                d.sucursal,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _oscuro,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _dorado, thickness: 1.5),
        pw.SizedBox(height: 4),

        // Datos del turno.
        fila('Vendedor', d.vendedor),
        fila(
          'Apertura',
          d.apertura == null ? 'Sin registro' : _fechaHora(d.apertura!),
        ),
        fila('Cierre', _fechaHora(d.cierre)),
        if (d.apertura != null && _duracion(d.apertura!, d.cierre).isNotEmpty)
          fila('Duración del turno', _duracion(d.apertura!, d.cierre)),

        titulo('Resumen de ventas'),
        fila('Cantidad de ventas', '${r.cantidadVentas}'),
        fila('Ticket promedio', formatearPesos(r.ticketPromedio)),
        fila('Vendido en efectivo', formatearPesos(r.vendidoEfectivo)),
        fila('Vendido con tarjeta', formatearPesos(r.vendidoTarjeta)),
        fila('Vendido a crédito', formatearPesos(r.vendidoCredito)),
        fila('Total vendido', formatearPesos(r.total), fuerte: true),
        if (d.anuladas > 0)
          fila('Ventas anuladas (no suman)', '${d.anuladas}', color: _gris),

        titulo('Cuadratura de caja'),
        fila('Monto inicial en caja', formatearPesos(d.montoInicial)),
        fila('Efectivo que entró por ventas', formatearPesos(r.efectivoEnCaja)),
        fila(
          'Efectivo esperado en caja',
          formatearPesos(d.efectivoEsperado),
          fuerte: true,
        ),
        fila('Contado en billetes', formatearPesos(d.billetesContados)),
        fila('Contado en monedas', formatearPesos(d.monedasContadas)),
        fila('Total contado', formatearPesos(d.totalContado), fuerte: true),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: dif == 0 ? PdfColors.green700 : PdfColors.red700,
              width: 1,
            ),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            dif == 0
                ? 'Caja cuadrada'
                : dif > 0
                ? 'Sobrante: ${formatearPesos(dif)}'
                : 'Faltante: ${formatearPesos(-dif)}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: dif == 0 ? PdfColors.green700 : PdfColors.red700,
            ),
          ),
        ),

        titulo('Productos vendidos'),
        if (d.productos.isEmpty)
          pw.Text(
            'No hubo ventas en este turno.',
            style: const pw.TextStyle(fontSize: 10, color: _gris),
          )
        else
          tabla(
            ['Producto', 'Unidades', 'Monto'],
            [
              for (final p in d.productos)
                [p.nombre, '${p.unidades}', formatearPesos(p.monto)],
            ],
            anchos: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1.4),
              2: const pw.FlexColumnWidth(2),
            },
            derecha: {1, 2},
          ),

        // Firmas.
        pw.SizedBox(height: 46),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            for (final quien in ['Vendedor', 'Supervisor'])
              pw.Column(
                children: [
                  pw.Container(width: 150, height: 0.8, color: _oscuro),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    quien,
                    style: const pw.TextStyle(fontSize: 9, color: _gris),
                  ),
                ],
              ),
          ],
        ),
        // El detalle va en hoja aparte: la primera queda como resumen para
        // firmar y archivar, y el detalle puede ocupar las páginas que necesite.
        if (d.ventas.isNotEmpty) ...[
          pw.NewPage(),
          titulo('Detalle de ventas'),
          tabla(
            ['Hora', 'Método', 'Cliente', 'Total'],
            [
              for (final v in d.ventas)
                [
                  _hora(v.hora),
                  v.anulada ? '${v.metodo} (anulada)' : v.metodo,
                  v.cliente.isEmpty ? '-' : v.cliente,
                  formatearPesos(v.total),
                ],
            ],
            anchos: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(2.4),
              2: const pw.FlexColumnWidth(3.4),
              3: const pw.FlexColumnWidth(2),
            },
            derecha: {3},
            filasTenues: {
              for (var i = 0; i < d.ventas.length; i++)
                if (d.ventas[i].anulada) i,
            },
          ),
        ],
      ],
    ),
  );

  return doc.save();
}
