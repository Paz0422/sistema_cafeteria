import 'package:flutter/material.dart';
import '../theme/marca.dart';

const rutaLogo = 'assets/images/logo.png';
const rutaMascota = 'assets/images/mascota.png';

/// El logo de Fusión (assets/images/logo.png). Mientras ese archivo no esté,
/// se dibuja una versión simple en código para que la app se vea completa.
class LogoFusion extends StatelessWidget {
  final double tamano;

  const LogoFusion({super.key, this.tamano = 140});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Image.asset(
        rutaLogo,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _LogoDibujado(tamano: tamano),
      ),
    );
  }
}

class _LogoDibujado extends StatelessWidget {
  final double tamano;

  const _LogoDibujado({required this.tamano});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Marca.negro,
        border: Border.all(color: Marca.cafe, width: tamano * 0.05),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Fusión',
            style: TextStyle(
              fontFamily: Marca.fuente,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              fontSize: tamano * 0.215,
              color: Marca.dorado,
              height: 1,
            ),
          ),
          SizedBox(height: tamano * 0.03),
          Text(
            'HEALTHY SNACKS & COFFEE',
            style: TextStyle(
              fontFamily: Marca.fuente,
              fontWeight: FontWeight.w600,
              fontSize: tamano * 0.055,
              letterSpacing: 0.5,
              color: Marca.dorado,
            ),
          ),
        ],
      ),
    );
  }
}

/// La mascota de Fusión (assets/images/mascota.png). Sin el archivo, muestra
/// un ícono de café dorado.
class MascotaFusion extends StatelessWidget {
  final double tamano;

  const MascotaFusion({super.key, this.tamano = 160});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Image.asset(
        rutaMascota,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Marca.doradoSuave,
          ),
          child: Icon(
            Icons.local_cafe_rounded,
            size: tamano * 0.5,
            color: Marca.cafe,
          ),
        ),
      ),
    );
  }
}
