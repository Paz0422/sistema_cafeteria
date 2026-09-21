import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'acceso.dart';

/// Restablece la contraseña de otra persona (lo hace un admin).
///
/// Firebase no permite cambiar la clave de otra cuenta desde la app, así que
/// se le crea un acceso nuevo con la contraseña temporal y se traspasa su
/// perfil (nombre, usuario y rol) al acceso nuevo. Todo el traspaso es una
/// sola escritura atómica: o queda hecho completo o no cambia nada.
///
/// El acceso nuevo se crea en una segunda instancia de Firebase para no
/// cerrar la sesión del admin.
Future<void> restablecerContrasena({
  required String uidAnterior,
  required String usuario,
  required String nombre,
  required String rol,
  required String contrasenaTemporal,
}) async {
  final db = FirebaseFirestore.instance;
  final refAcceso = db.collection('accesos').doc(idAcceso(usuario));
  final actual = (await refAcceso.get()).data()?['gen'] as num?;
  var generacion = (actual?.toInt() ?? 1) + 1;

  final app = await Firebase.initializeApp(
    name: 'restablecer-${DateTime.now().microsecondsSinceEpoch}',
    options: Firebase.app().options,
  );
  try {
    final auth = FirebaseAuth.instanceFor(app: app);

    // Si una vez anterior falló a medias y ya existe el acceso de esa
    // generación, se sigue con la siguiente.
    UserCredential? credencial;
    for (var intento = 0; credencial == null; intento++) {
      try {
        credencial = await auth.createUserWithEmailAndPassword(
          email: correoDeAcceso(usuario, generacion: generacion),
          password: contrasenaTemporal,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use' || intento >= 5) rethrow;
        generacion++;
      }
    }

    final lote = db.batch()
      ..set(db.collection('usuarios').doc(credencial.user!.uid), {
        'nombre': nombre,
        'usuario': usuario,
        'rol': rol,
        'debeCambiarClave': true,
      })
      ..set(refAcceso, {'gen': generacion})
      ..delete(db.collection('usuarios').doc(uidAnterior));
    await lote.commit();

    await auth.signOut();
  } finally {
    await app.delete();
  }
}
