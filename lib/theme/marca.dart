import 'package:flutter/material.dart';

/// Identidad visual de Fusión: un tema oscuro "café" con dorado como acento,
/// sacado del logo. Todas las pantallas leen sus colores de aquí.
class Marca {
  Marca._();

  // Fondos, de más profundo a más elevado.
  static const negro = Color(0xFF0A0908);
  static const fondo = Color(0xFF0E0C0A);
  static const carbon = Color(0xFF14110F);
  static const superficie = Color(0xFF1A1714);
  static const superficieAlta = Color(0xFF231F1A);
  static const carbonClaro = Color(0xFF2A251F);

  static const borde = Color(0xFF2E2922);
  static const bordeSuave = Color(0xFF221E19);

  // Acentos.
  static const dorado = Color(0xFFF2BE3A);
  static const doradoClaro = Color(0xFFFFDA7A);
  static const doradoSuave = Color(0xFF33280F);
  static const cafe = Color(0xFFB98544);

  // Texto.
  static const texto = Color(0xFFF6F0E4);
  static const textoSuave = Color(0xFFA89F90);
  static const textoSobreOscuro = Color(0xFFD9D2C5);

  // Estados.
  static const exito = Color(0xFF5FCB8A);
  static const peligro = Color(0xFFFF6B5E);
  static const alerta = Color(0xFFFFA94D);
  static const avisoFondo = Color(0xFF3A2A12);
  static const avisoTexto = Color(0xFFFFB35C);

  static const fuente = 'Poppins';

  /// Degradado dorado de los elementos destacados (botones, íconos, barras).
  static const degradadoDorado = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [doradoClaro, dorado, Color(0xFFD99A1F)],
  );

  /// Degradado sutil de las tarjetas: un poco más claro arriba a la izquierda.
  static const degradadoTarjeta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF242019), Color(0xFF181512)],
  );

  /// Sombra de las tarjetas elevadas (sobre fondo oscuro es solo profundidad).
  static List<BoxShadow> get sombraSuave => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  /// Resplandor dorado para lo que se quiere resaltar.
  static List<BoxShadow> get brilloDorado => [
    BoxShadow(
      color: dorado.withValues(alpha: 0.28),
      blurRadius: 22,
      spreadRadius: -2,
    ),
  ];
}

ThemeData temaFusion() {
  const esquema = ColorScheme.dark(
    primary: Marca.dorado,
    onPrimary: Marca.negro,
    primaryContainer: Marca.doradoSuave,
    onPrimaryContainer: Marca.doradoClaro,
    secondary: Marca.cafe,
    onSecondary: Marca.negro,
    secondaryContainer: Marca.doradoSuave,
    onSecondaryContainer: Marca.doradoClaro,
    tertiary: Marca.exito,
    error: Marca.peligro,
    onError: Marca.negro,
    surface: Marca.superficie,
    onSurface: Marca.texto,
    onSurfaceVariant: Marca.textoSuave,
    surfaceContainerLowest: Marca.negro,
    surfaceContainerLow: Marca.carbon,
    surfaceContainer: Marca.superficie,
    surfaceContainerHigh: Marca.superficieAlta,
    surfaceContainerHighest: Marca.carbonClaro,
    outline: Color(0xFF5A5246),
    outlineVariant: Marca.borde,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: esquema,
    fontFamily: Marca.fuente,
    scaffoldBackgroundColor: Marca.fondo,
    canvasColor: Marca.superficieAlta,
    dividerColor: Marca.borde,
    splashFactory: InkSparkle.splashFactory,
  );

  const radioTarjeta = 22.0;
  final bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Marca.borde),
  );
  final formaBoton = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  const estiloBoton = TextStyle(
    fontFamily: Marca.fuente,
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );

  return base.copyWith(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Marca.carbon,
      foregroundColor: Marca.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: Marca.borde)),
      iconTheme: IconThemeData(color: Marca.dorado),
      actionsIconTheme: IconThemeData(color: Marca.dorado),
      titleTextStyle: TextStyle(
        fontFamily: Marca.fuente,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Marca.texto,
      ),
    ),
    cardTheme: CardThemeData(
      color: Marca.superficie,
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
      backgroundColor: Marca.superficieAlta,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: Marca.borde),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: Marca.fuente,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Marca.texto,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: Marca.fuente,
        fontSize: 14,
        color: Marca.textoSobreOscuro,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Marca.superficieAlta,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Marca.superficieAlta,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Marca.borde),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Marca.superficieAlta),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Marca.dorado,
        foregroundColor: Marca.negro,
        disabledBackgroundColor: Marca.carbonClaro,
        disabledForegroundColor: const Color(0xFF6E665A),
        textStyle: estiloBoton,
        shape: formaBoton,
        minimumSize: const Size(48, 48),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Marca.dorado,
        foregroundColor: Marca.negro,
        disabledBackgroundColor: Marca.carbonClaro,
        disabledForegroundColor: const Color(0xFF6E665A),
        elevation: 0,
        textStyle: estiloBoton,
        shape: formaBoton,
        minimumSize: const Size(48, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Marca.dorado,
        side: BorderSide(color: Marca.dorado.withValues(alpha: 0.55)),
        textStyle: estiloBoton,
        shape: formaBoton,
        minimumSize: const Size(48, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Marca.dorado,
        textStyle: estiloBoton.copyWith(fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: Marca.dorado),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Marca.carbon,
      border: bordeCampo,
      enabledBorder: bordeCampo,
      disabledBorder: bordeCampo.copyWith(
        borderSide: BorderSide(color: Marca.borde.withValues(alpha: 0.5)),
      ),
      focusedBorder: bordeCampo.copyWith(
        borderSide: const BorderSide(color: Marca.dorado, width: 1.6),
      ),
      errorBorder: bordeCampo.copyWith(
        borderSide: const BorderSide(color: Marca.peligro),
      ),
      focusedErrorBorder: bordeCampo.copyWith(
        borderSide: const BorderSide(color: Marca.peligro, width: 1.6),
      ),
      labelStyle: const TextStyle(color: Marca.textoSuave),
      hintStyle: const TextStyle(color: Marca.textoSuave),
      prefixIconColor: WidgetStateColor.resolveWith(
        (e) =>
            e.contains(WidgetState.focused) ? Marca.dorado : Marca.textoSuave,
      ),
      suffixIconColor: Marca.textoSuave,
      floatingLabelStyle: const TextStyle(color: Marca.dorado),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Marca.dorado,
      selectionColor: Marca.dorado.withValues(alpha: 0.3),
      selectionHandleColor: Marca.dorado,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Marca.superficie,
      selectedColor: Marca.dorado,
      side: const BorderSide(color: Marca.borde),
      shape: const StadiumBorder(),
      checkmarkColor: Marca.negro,
      iconTheme: const IconThemeData(color: Marca.dorado),
      labelStyle: TextStyle(
        fontFamily: Marca.fuente,
        color: WidgetStateColor.resolveWith(
          (e) => e.contains(WidgetState.selected) ? Marca.negro : Marca.texto,
        ),
        fontWeight: FontWeight.w500,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected)
              ? Marca.dorado
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? Marca.negro : Marca.texto,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? Marca.negro : Marca.dorado,
        ),
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
      unselectedIconTheme: const IconThemeData(color: Marca.textoSuave),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: Marca.fuente,
        color: Marca.dorado,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: Marca.fuente,
        color: Marca.textoSuave,
        fontSize: 12,
      ),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: Marca.carbon,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Marca.dorado,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (e) => IconThemeData(
          color: e.contains(WidgetState.selected)
              ? Marca.negro
              : Marca.textoSuave,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (e) => TextStyle(
          fontFamily: Marca.fuente,
          fontWeight: e.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: e.contains(WidgetState.selected)
              ? Marca.dorado
              : Marca.textoSobreOscuro,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Marca.carbonClaro,
      contentTextStyle: const TextStyle(
        fontFamily: Marca.fuente,
        color: Marca.texto,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Marca.borde),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (e) => e.contains(WidgetState.selected)
            ? Marca.negro
            : const Color(0xFF8A8072),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (e) =>
            e.contains(WidgetState.selected) ? Marca.dorado : Marca.carbonClaro,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (e) => e.contains(WidgetState.selected)
            ? Marca.dorado
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Marca.negro),
      side: const BorderSide(color: Marca.textoSuave, width: 1.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (e) =>
            e.contains(WidgetState.selected) ? Marca.dorado : Marca.textoSuave,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Marca.dorado,
      linearTrackColor: Marca.dorado.withValues(alpha: 0.12),
      circularTrackColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Marca.dorado,
      textColor: Marca.texto,
      subtitleTextStyle: TextStyle(
        fontFamily: Marca.fuente,
        fontSize: 13,
        color: Marca.textoSuave,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Marca.carbonClaro,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Marca.borde),
      ),
      textStyle: const TextStyle(
        fontFamily: Marca.fuente,
        fontSize: 12,
        color: Marca.texto,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Marca.dorado.withValues(alpha: 0.35)),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
      iconColor: Marca.dorado,
      collapsedIconColor: Marca.textoSuave,
    ),
  );
}
