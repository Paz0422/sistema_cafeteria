import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/marca.dart';

/// Un tramo de la dona: su nombre, cuánto vale y de qué color se pinta.
class TramoDona {
  final String nombre;
  final int valor;
  final Color color;

  const TramoDona(this.nombre, this.valor, this.color);
}

/// Dona animada. En el centro va [centro] (por ejemplo el total).
class DonaFusion extends StatelessWidget {
  final List<TramoDona> tramos;
  final Widget centro;
  final double tamano;

  const DonaFusion({
    super.key,
    required this.tramos,
    required this.centro,
    this.tamano = 150,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (context, progreso, hijo) =>
            CustomPaint(painter: _DonaPainter(tramos, progreso), child: hijo),
        child: Center(child: centro),
      ),
    );
  }
}

class _DonaPainter extends CustomPainter {
  final List<TramoDona> tramos;
  final double progreso;

  _DonaPainter(this.tramos, this.progreso);

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 16.0;
    final rect = Offset.zero & size;
    final area = rect.deflate(grosor / 2);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(area, 0, math.pi * 2, false, pincel..color = Marca.borde);

    final total = tramos.fold<int>(0, (a, t) => a + t.valor);
    if (total == 0) return;

    // Un pequeño hueco entre tramos, salvo que haya uno solo.
    final visibles = tramos.where((t) => t.valor > 0).toList();
    final hueco = visibles.length > 1 ? 0.16 : 0.0;
    var inicio = -math.pi / 2;
    for (final tramo in visibles) {
      final barrido = (tramo.valor / total) * math.pi * 2 * progreso;
      final largo = math.max(barrido - hueco, 0.001);
      canvas.drawArc(
        area,
        inicio + hueco / 2,
        largo,
        false,
        pincel..color = tramo.color,
      );
      inicio += barrido;
    }
  }

  @override
  bool shouldRepaint(_DonaPainter viejo) =>
      viejo.progreso != progreso || viejo.tramos != tramos;
}

/// Una barra del gráfico: su etiqueta corta, la larga (para el detalle al
/// tocarla) y su valor.
class PuntoBarra {
  final String etiqueta;
  final String detalle;
  final int valor;

  const PuntoBarra(this.etiqueta, this.detalle, this.valor);
}

/// Barras verticales animadas. Al tocar (o arrastrar sobre) una barra se
/// resalta y se avisa con [alSeleccionar].
class GraficoBarrasFusion extends StatelessWidget {
  final List<PuntoBarra> puntos;
  final int? seleccionado;
  final ValueChanged<int> alSeleccionar;
  final double alto;

  const GraficoBarrasFusion({
    super.key,
    required this.puntos,
    required this.seleccionado,
    required this.alSeleccionar,
    this.alto = 190,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        void elegir(double dx) {
          if (puntos.isEmpty) return;
          final indice = (dx / c.maxWidth * puntos.length).floor().clamp(
            0,
            puntos.length - 1,
          );
          alSeleccionar(indice);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => elegir(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => elegir(d.localPosition.dx),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, progreso, _) => CustomPaint(
              size: Size(c.maxWidth, alto),
              painter: _BarrasPainter(puntos, seleccionado, progreso),
            ),
          ),
        );
      },
    );
  }
}

class _BarrasPainter extends CustomPainter {
  final List<PuntoBarra> puntos;
  final int? seleccionado;
  final double progreso;

  _BarrasPainter(this.puntos, this.seleccionado, this.progreso);

  @override
  void paint(Canvas canvas, Size size) {
    const altoEtiquetas = 24.0;
    final altoBarras = size.height - altoEtiquetas;
    final n = puntos.length;
    if (n == 0) return;

    // Líneas guía.
    final guia = Paint()
      ..color = Marca.borde.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = altoBarras * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guia);
    }

    final maximo = puntos.fold<int>(0, (a, p) => math.max(a, p.valor));
    final ancho = size.width / n;
    final anchoBarra = math.min(ancho * 0.62, 34.0);
    // Con muchas barras solo se rotulan algunas para que no se pisen.
    final paso = (n / (size.width / 46)).ceil().clamp(1, n);

    for (var i = 0; i < n; i++) {
      final p = puntos[i];
      final centro = ancho * (i + 0.5);
      final activa = seleccionado == null || seleccionado == i;
      final proporcion = maximo == 0 ? 0.0 : p.valor / maximo;
      final altura = math.max(proporcion * (altoBarras - 6) * progreso, 4.0);
      final barra = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          centro - anchoBarra / 2,
          altoBarras - altura,
          anchoBarra,
          altura,
        ),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      );

      final relleno = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: activa
              ? [Marca.doradoClaro, Marca.dorado, Marca.cafe]
              : [
                  Marca.dorado.withValues(alpha: 0.35),
                  Marca.cafe.withValues(alpha: 0.25),
                ],
        ).createShader(barra.outerRect);
      if (seleccionado == i) {
        canvas.drawRRect(
          barra,
          Paint()
            ..color = Marca.dorado.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
      canvas.drawRRect(barra, relleno);

      if (i % paso == 0 || seleccionado == i) {
        final texto = TextPainter(
          text: TextSpan(
            text: p.etiqueta,
            style: TextStyle(
              fontFamily: Marca.fuente,
              fontSize: 11,
              fontWeight: seleccionado == i ? FontWeight.w700 : FontWeight.w400,
              color: seleccionado == i ? Marca.dorado : Marca.textoSuave,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: ancho * paso);
        texto.paint(canvas, Offset(centro - texto.width / 2, altoBarras + 8));
      }
    }
  }

  @override
  bool shouldRepaint(_BarrasPainter viejo) =>
      viejo.progreso != progreso ||
      viejo.seleccionado != seleccionado ||
      viejo.puntos != puntos;
}

/// Barra horizontal fina con degradado que se llena al aparecer.
class BarraFusion extends StatelessWidget {
  /// Entre 0 y 1.
  final double proporcion;
  final double alto;

  const BarraFusion({super.key, required this.proporcion, this.alto = 8});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(alto),
      child: Container(
        height: alto,
        color: Marca.dorado.withValues(alpha: 0.10),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: proporcion.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Marca.cafe, Marca.dorado],
                ),
                borderRadius: BorderRadius.circular(alto),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Puntito que "late", para indicar algo que está pasando ahora.
class PuntoVivo extends StatefulWidget {
  final Color color;

  const PuntoVivo({super.key, this.color = Marca.exito});

  @override
  State<PuntoVivo> createState() => _PuntoVivoState();
}

class _PuntoVivoState extends State<PuntoVivo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _controlador,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 18 * _controlador.value,
              height: 18 * _controlador.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(
                  alpha: 0.5 * (1 - _controlador.value),
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
