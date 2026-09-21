import 'package:flutter/material.dart';

import '../theme/marca.dart';

/// Fondo de las pantallas: negro café con dos resplandores dorados muy
/// tenues, para que las tarjetas oscuras tengan algo de profundidad.
class FondoFusion extends StatelessWidget {
  final Widget child;

  const FondoFusion({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Marca.fondo),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-1.0, -1.1),
                  radius: 1.1,
                  colors: [
                    Marca.dorado.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.1, 1.1),
                  radius: 1.0,
                  colors: [
                    Marca.cafe.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Tarjeta con degradado sutil y borde fino. Con [brillo] se resalta con un
/// halo dorado; con [onTap] responde al toque.
class TarjetaFusion extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool brillo;
  final VoidCallback? onTap;
  final double radio;

  const TarjetaFusion({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.brillo = false,
    this.onTap,
    this.radio = 22,
  });

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(radio);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: forma,
        gradient: Marca.degradadoTarjeta,
        border: Border.all(
          color: brillo ? Marca.dorado.withValues(alpha: 0.45) : Marca.borde,
        ),
        boxShadow: brillo ? Marca.brilloDorado : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: forma,
        child: InkWell(
          borderRadius: forma,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Ícono sobre un cuadro redondeado con degradado dorado.
class IconoDorado extends StatelessWidget {
  final IconData icono;
  final double tamano;

  const IconoDorado(this.icono, {super.key, this.tamano = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(tamano * 0.42),
      decoration: BoxDecoration(
        gradient: Marca.degradadoDorado,
        borderRadius: BorderRadius.circular(tamano * 0.7),
        boxShadow: Marca.brilloDorado,
      ),
      child: Icon(icono, size: tamano, color: Marca.negro),
    );
  }
}

/// Cuenta desde el valor anterior hasta [valor] (o desde cero la primera
/// vez), para que las cifras "se llenen" al cargar o al cambiar el filtro.
class NumeroAnimado extends StatelessWidget {
  final int valor;
  final String Function(int) formato;
  final TextStyle? estilo;
  final Duration duracion;

  const NumeroAnimado({
    super.key,
    required this.valor,
    required this.formato,
    this.estilo,
    this.duracion = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: valor.toDouble()),
      duration: duracion,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text(formato(v.round()), style: estilo, maxLines: 1),
    );
  }
}

/// Hace aparecer a [child] con un desvanecido y un leve ascenso. Con
/// [indice] las apariciones de una lista se escalonan una tras otra.
class Aparecer extends StatelessWidget {
  final Widget child;
  final int indice;

  const Aparecer({super.key, required this.child, this.indice = 0});

  @override
  Widget build(BuildContext context) {
    final retraso = (indice * 70).clamp(0, 560);
    final total = 420 + retraso;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(retraso / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, hijo) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 18),
          child: hijo,
        ),
      ),
      child: child,
    );
  }
}

/// Título de sección con una barrita dorada al costado.
class TituloSeccion extends StatelessWidget {
  final String texto;
  final Widget? accion;

  const TituloSeccion(this.texto, {super.key, this.accion});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: Marca.degradadoDorado,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Marca.texto,
              letterSpacing: 0.2,
            ),
          ),
        ),
        ?accion,
      ],
    );
  }
}
