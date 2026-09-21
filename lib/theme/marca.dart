import 'package:flutter/material.dart';

/// Colores de la marca, sacados del logo: negro, dorado y el café del aro.
class Marca {
  Marca._();

  static const negro = Color(0xFF141414);
  static const carbon = Color(0xFF232323);
  static const carbonClaro = Color(0xFF2F2F2F);

  static const dorado = Color(0xFFF2BE3A);
  static const doradoSuave = Color(0xFFFFF0C4);

  static const cafe = Color(0xFF8A5A2B);

  static const fondo = Color(0xFFF6F3EE);
  static const borde = Color(0xFFE6DFD3);
  static const textoSuave = Color(0xFF6B655C);
  static const textoSobreOscuro = Color(0xFFD9D2C5);

  static const avisoFondo = Color(0xFFFAEBD2);
  static const avisoTexto = Color(0xFFB85A00);

  static const fuente = 'Poppins';

  /// Sombra suave de las tarjetas (la misma en todas las pantallas).
  static List<BoxShadow> get sombraSuave => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

ThemeData temaFusion() {
  final esquema =
      ColorScheme.fromSeed(
        seedColor: Marca.dorado,
        brightness: Brightness.light,
      ).copyWith(
        // El café es el color "de texto" de la marca: se lee bien sobre
        // blanco. El dorado se reserva para rellenos (botones, selección).
        primary: Marca.cafe,
        onPrimary: Colors.white,
        primaryContainer: Marca.doradoSuave,
        onPrimaryContainer: const Color(0xFF3B2610),
        secondary: Marca.dorado,
        onSecondary: Marca.negro,
        secondaryContainer: Marca.doradoSuave,
        onSecondaryContainer: Marca.negro,
        surface: Colors.white,
        onSurface: const Color(0xFF1B1B1B),
        surfaceContainerHighest: const Color(0xFFEFEAE1),
        outline: const Color(0xFFB9B0A2),
        outlineVariant: Marca.borde,
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: Marca.fuente,
    scaffoldBackgroundColor: Marca.fondo,
    dividerColor: Marca.borde,
  );

  const radioTarjeta = 20.0;
  final bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Marca.borde),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Marca.negro,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      iconTheme: IconThemeData(color: Marca.dorado),
      actionsIconTheme: IconThemeData(color: Marca.dorado),
      titleTextStyle: TextStyle(
        fontFamily: Marca.fuente,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radioTarjeta),
        side: const BorderSide(color: Marca.borde),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        fontFamily: Marca.fuente,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1B1B1B),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Marca.dorado,
        foregroundColor: Marca.negro,
        disabledBackgroundColor: const Color(0xFFEAE4D8),
        disabledForegroundColor: const Color(0xFFA59D90),
        textStyle: const TextStyle(
          fontFamily: Marca.fuente,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(48, 48),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Marca.dorado,
        foregroundColor: Marca.negro,
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: Marca.fuente,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(48, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Marca.negro,
        side: const BorderSide(color: Marca.cafe),
        textStyle: const TextStyle(
          fontFamily: Marca.fuente,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(48, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Marca.cafe,
        textStyle: const TextStyle(
          fontFamily: Marca.fuente,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: bordeCampo,
      enabledBorder: bordeCampo,
      disabledBorder: bordeCampo.copyWith(
        borderSide: BorderSide(color: Marca.borde.withValues(alpha: 0.6)),
      ),
      focusedBorder: bordeCampo.copyWith(
        borderSide: const BorderSide(color: Marca.dorado, width: 2),
      ),
      errorBorder: bordeCampo.copyWith(
        borderSide: const BorderSide(color: Color(0xFFC0392B)),
      ),
      focusedErrorBorder: bordeCampo.copyWith(
        borderSide: const BorderSide(color: Color(0xFFC0392B), width: 2),
      ),
      floatingLabelStyle: const TextStyle(color: Marca.cafe),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: Marca.dorado,
      side: const BorderSide(color: Marca.borde),
      shape: const StadiumBorder(),
      checkmarkColor: Marca.negro,
      labelStyle: const TextStyle(
        fontFamily: Marca.fuente,
        color: Marca.negro,
        fontWeight: FontWeight.w500,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? Marca.dorado
              : Colors.white,
        ),
        foregroundColor: const WidgetStatePropertyAll(Marca.negro),
        side: const WidgetStatePropertyAll(BorderSide(color: Marca.borde)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Marca.carbon,
      indicatorColor: Marca.dorado,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      selectedIconTheme: const IconThemeData(color: Marca.negro),
      unselectedIconTheme: const IconThemeData(color: Marca.textoSobreOscuro),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: Marca.fuente,
        color: Marca.dorado,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: Marca.fuente,
        color: Marca.textoSobreOscuro,
        fontSize: 12,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Marca.carbon,
      contentTextStyle: const TextStyle(
        fontFamily: Marca.fuente,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected)
            ? Marca.negro
            : const Color(0xFF9C948A),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected)
            ? Marca.dorado
            : const Color(0xFFE6DFD3),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Marca.cafe),
    listTileTheme: const ListTileThemeData(iconColor: Marca.cafe),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}
