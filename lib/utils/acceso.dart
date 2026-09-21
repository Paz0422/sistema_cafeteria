import 'dart:math';

import '../constants.dart';

/// Nombre de usuario tal como se guarda y se compara: sin espacios y en
/// minúsculas.
String normalizarUsuario(String texto) => texto.trim().toLowerCase();

/// Correo interno con el que una persona existe en Firebase Auth.
///
/// Firebase no deja que una app cambie la contraseña de otra cuenta, así que
/// cuando un admin restablece un acceso se crea una cuenta de acceso nueva
/// (una "generación" más). La primera generación es `usuario@dominio`; las
/// siguientes agregan `+gN`. Qué generación vale para cada usuario lo dice
/// `accesos/{usuario}` en Firestore.
String correoDeAcceso(String usuario, {int generacion = 1}) => generacion <= 1
    ? '$usuario$dominioInterno'
    : '$usuario+g$generacion$dominioInterno';

/// Id del documento `accesos/{...}` de un usuario. Un id de Firestore no puede
/// llevar `/`, así que se codifica.
String idAcceso(String usuario) => Uri.encodeComponent(usuario);

/// Contraseña temporal legible: sin letras que se confundan (0/O, 1/l/I).
String generarContrasenaTemporal({Random? azar, int largo = 8}) {
  const letras = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = azar ?? Random.secure();
  return List.generate(largo, (_) => letras[r.nextInt(letras.length)]).join();
}
