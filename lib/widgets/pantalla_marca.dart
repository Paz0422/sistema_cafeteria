import 'package:flutter/material.dart';
import '../theme/marca.dart';
import 'logo_fusion.dart';
import 'premium.dart';

/// Marco de las pantallas de acceso (login y registro): fondo negro con el
/// logo, una tarjeta blanca para el formulario y, en pantallas anchas
/// (tablet horizontal o PC), la mascota al costado.
class PantallaMarca extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget contenido;
  final Widget? pie;

  const PantallaMarca({
    super.key,
    required this.titulo,
    required this.contenido,
    this.subtitulo,
    this.pie,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Marca.negro,
      body: FondoFusion(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final ancho = constraints.maxWidth >= 900;
              final formulario = _TarjetaFormulario(
                titulo: titulo,
                subtitulo: subtitulo,
                contenido: contenido,
                pie: pie,
              );

              if (ancho) {
                return Row(
                  children: [
                    // Con poco alto (por ejemplo, teclado abierto en una tablet
                    // horizontal) se deja solo el logo para que todo quepa.
                    Expanded(
                      child: _PanelMarca(
                        mostrarMascota: constraints.maxHeight >= 620,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Aparecer(indice: 1, child: formulario),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Aparecer(child: LogoFusion(tamano: 120)),
                        const SizedBox(height: 24),
                        Aparecer(indice: 1, child: formulario),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PanelMarca extends StatelessWidget {
  final bool mostrarMascota;

  const _PanelMarca({required this.mostrarMascota});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Aparecer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: Marca.brilloDorado,
              ),
              child: const LogoFusion(tamano: 190),
            ),
          ),
          if (mostrarMascota) ...[
            const SizedBox(height: 16),
            Aparecer(
              indice: 2,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Marca.dorado.withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const MascotaFusion(tamano: 260),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Aparecer(
              indice: 3,
              child: Text(
                'Punto de venta e inventario',
                style: TextStyle(
                  color: Marca.textoSuave,
                  fontSize: 15,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaFormulario extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget contenido;
  final Widget? pie;

  const _TarjetaFormulario({
    required this.titulo,
    required this.contenido,
    this.subtitulo,
    this.pie,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: Marca.degradadoTarjeta,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Marca.dorado.withValues(alpha: 0.30)),
            boxShadow: [...Marca.sombraSuave, ...Marca.brilloDorado],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Marca.texto,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitulo!,
                  style: const TextStyle(color: Marca.textoSuave),
                ),
              ],
              const SizedBox(height: 24),
              contenido,
            ],
          ),
        ),
        if (pie != null) ...[const SizedBox(height: 12), pie!],
      ],
    );
  }
}

/// Botón de texto para el pie de las pantallas oscuras (dorado sobre negro).
class BotonPieMarca extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;

  const BotonPieMarca({
    super.key,
    required this.texto,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: Marca.dorado),
      child: Text(texto),
    );
  }
}
