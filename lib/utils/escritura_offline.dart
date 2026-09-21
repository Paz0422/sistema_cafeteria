import 'dart:async';

/// Espera la confirmación del servidor solo unos segundos.
///
/// Con la persistencia de Firestore activa, una escritura sin internet queda
/// guardada en el dispositivo y se envía sola al volver la conexión, pero su
/// Future no termina hasta que el servidor responde. Si la pantalla esperara
/// ese Future, se quedaría cargando para siempre.
///
/// Devuelve `true` si el servidor confirmó a tiempo, o `false` si la
/// escritura quedó pendiente de sincronizar. Si el servidor la rechaza dentro
/// del plazo, el error se propaga; si la rechaza después, se avisa con
/// [siFallaDespues].
Future<bool> esperarConfirmacion(
  Future<void> escritura, {
  Duration espera = const Duration(seconds: 3),
  void Function(Object error)? siFallaDespues,
}) {
  final resultado = Completer<bool>();

  escritura.then(
    (_) {
      if (!resultado.isCompleted) resultado.complete(true);
    },
    onError: (Object error) {
      if (!resultado.isCompleted) {
        resultado.completeError(error);
      } else {
        siFallaDespues?.call(error);
      }
    },
  );

  Timer(espera, () {
    if (!resultado.isCompleted) resultado.complete(false);
  });

  return resultado.future;
}
