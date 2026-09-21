# Cafetería Fusión — Sistema de punto de venta e inventario

Aplicación web (Flutter + Firebase) para llevar el punto de venta, el inventario
y los clientes con crédito de una o varias cafeterías. Está pensada para usarse
en **PC y tablet**, con lector de códigos de barras USB.

> No procesa pagos: solo registra las ventas y el inventario. Las tarjetas se
> cobran con el terminal que ya usen.

## Qué hace

**Punto de venta (vendedor)**
- Escaneo de códigos de barras (lector USB tipo teclado) y carrito.
- Varias cuentas abiertas a la vez (un cliente en espera mientras se atiende a otro).
- Atajo `+` para sumar otra unidad del último producto escaneado.
- Promociones por pack: "cada N por $X" (el pack cuesta $X sin importar el precio unitario).
- Pago en efectivo (con vuelto), tarjeta, mixto o **crédito** a un cliente.
- Turnos: apertura de caja (billetes y monedas), cierre con cuadratura de efectivo.
- Historial de ventas del turno: el vendedor puede **cancelar** una venta de su
  turno abierto (revierte stock y deuda); **corregirla** (cambiar producto) es
  solo del admin.
- Funciona sin internet (ver [Uso sin conexión](#uso-sin-conexión)).

**Inventario**
- Catálogo único de productos y precios; el **stock es por sucursal**.
- Productos sin control de stock (`controlaStock`) para lo que no se cuenta.
- Rechazo de códigos de barras duplicados al crear o editar.
- Historial de movimientos de stock (quién agregó o ajustó qué, y cuándo).

**Clientes y crédito**
- Límite de crédito por cliente, validado en el servidor al vender.
- Abonos a la deuda.
- Clientes compartidos entre sucursales relacionadas (por ejemplo, la cafetería
  principal y su kiosko de eventos), configurable por sucursal.

**Administración**
- Estadísticas por rango de fechas (hoy, ayer, 7 días, mes o personalizado) y
  por sucursal: totales, ticket promedio, método de pago, ventas por día o mes,
  productos más vendidos, stock bajo y clientes con deuda.
- Gestión de usuarios y roles, sucursales, productos y clientes.
- "Panel vendedor": el admin puede operar el punto de venta con todos los permisos.

## Roles

| Rol | Puede |
| --- | --- |
| `admin` | Todo: productos, precios, stock, usuarios, sucursales, estadísticas, cancelar ventas. |
| `vendedor` | Vender, ver sus propias ventas y turnos, crear productos y clientes, **agregar** stock y registrar abonos. No puede editar ni eliminar productos, ni ver estadísticas. |
| `pendiente` | Sin acceso. Sirve para desactivar una cuenta. |

Un vendedor **no está atado a una sucursal**: al abrir turno elige en cuál va a
trabajar ese día.

## Tecnologías

- [Flutter](https://flutter.dev) (Dart 3, Material 3), compilado a web.
- Firebase: Authentication (correo y contraseña), Cloud Firestore y Hosting.
- Sin backend propio ni Cloud Functions: la seguridad vive en
  [`firestore.rules`](firestore.rules).

## Puesta en marcha (desarrollo)

Requisitos: [Flutter](https://docs.flutter.dev/get-started/install) (SDK `^3.12`)
y Google Chrome.

```bash
git clone https://github.com/Paz0422/sistema_cafeteria.git
cd sistema_cafeteria
flutter pub get
flutter run -d chrome
```

Comprobaciones antes de subir cambios:

```bash
flutter analyze
flutter test
```

Las pruebas cubren la aritmética de dinero (promos por pack, vuelto y efectivo
en caja de cada método de pago, límite de crédito), los totales del cierre de
turno y de los reportes por rango de fechas, el formato de pesos, el diálogo de
cobro completo y su diseño en tamaños de tablet. Los widgets que consultan
Firestore no tienen pruebas automáticas (necesitan Firebase).

## Configuración de Firebase (primera vez)

El proyecto ya apunta a `cafeteria-sistema-123ef` (ver `lib/main.dart` y
`.firebaserc`). Para montarlo en un proyecto nuevo:

1. **Authentication → Método de acceso**: habilita *Correo electrónico/contraseña*.
2. **Firestore Database**: crea la base de datos.
3. **Reglas**: publica el contenido de [`firestore.rules`](firestore.rules)
   (o usa `firebase deploy --only firestore:rules`).
4. **Código de invitación**: en Firestore crea la colección `config`, con el
   documento `registro` y un campo de texto `codigo` con la clave que se le
   entregará al personal. Nadie puede leerlo desde la app; se cambia desde la
   consola cuando haga falta. **No lo escribas en el código ni en git.**
5. **Primer administrador**: como solo un admin puede cambiar roles, el primero
   se crea a mano:
   1. Regístrate desde la app con el código de invitación (quedas como `vendedor`).
   2. En Firestore, abre `usuarios/{tu uid}` y cambia el campo `rol` a `admin`.
6. Crea al menos una **sucursal** desde el panel de admin antes de abrir turnos.

### Cómo se inicia sesión

Las personas usan un **nombre de usuario**, no un correo. Internamente se
convierte en `usuario@cafeteria.fusion` (constante `dominioInterno` en
`lib/constants.dart`); ese dominio no necesita existir.

### Si alguien olvida su contraseña

No se usan correos, así que la recuperación la hace un admin:

1. En **Usuarios**, el admin abre a la persona y toca **Restablecer contraseña**.
2. La app muestra una contraseña temporal (una sola vez): el admin se la pasa.
3. La persona entra con su usuario y esa contraseña, y el sistema le pide elegir
   una nueva antes de dejarla pasar.

Firebase no permite que una app cambie la contraseña de otra cuenta, así que el
restablecimiento crea un acceso nuevo (`usuario+gN@cafeteria.fusion`) y le
traspasa el perfil (nombre, usuario y rol). La generación vigente de cada
usuario está en `accesos/{usuario}`, y el login la consulta antes de entrar.
Consecuencias: el acceso anterior queda huérfano (sin perfil, no sirve para
nada) y las ventas y turnos antiguos siguen guardados con el identificador
anterior, así que el admin los ve en las estadísticas pero la persona ya no los
ve en su historial. Un admin no puede restablecer su propia contraseña: si es el
único admin y la olvida, hay que borrar su usuario en Authentication, volver a
registrarlo y cambiar su `rol` a `admin` en Firestore.

Estas reglas viven en `firestore.rules`: después de cambiarlas hay que
publicarlas en Firebase (`firebase deploy --only firestore:rules` o pegándolas
en la consola).

### Seguridad

- El código de invitación se valida **en las reglas de Firestore**, no en la app.
  Quien se registre con el código correcto queda como `vendedor`; nadie puede
  crearse a sí mismo como `admin`.
- Solo un admin cambia roles (y no el propio, para no quedarse sin admins).
- Sin ser `admin` o `vendedor`, ninguna colección es legible.
- Un vendedor solo puede: crear ventas propias en su turno abierto (con la fecha
  del servidor), **anular** una venta propia de un turno abierto (sin tocar
  montos ni productos), y **cerrar** su turno abierto. Un turno cerrado o el
  monto inicial no se pueden modificar.
- La deuda de un cliente nunca queda negativa y un vendedor no puede subirla por
  encima del límite de crédito (bajarla, con abonos o cancelaciones, sí).
- La `apiKey` de `lib/main.dart` es pública por diseño en Firebase; lo que
  protege los datos son las reglas.
- Recomendado: en Google Cloud Console → *APIs y servicios* → *Credenciales*,
  restringe la clave de navegador a tus dominios (el de Hosting, tu dominio
  propio y `localhost`).

## Despliegue en Firebase Hosting

La configuración está en [`firebase.json`](firebase.json) y `.firebaserc`.
Publica la app web y las reglas de Firestore.

**Una sola vez:**

```bash
npm install -g firebase-tools
firebase login
```

**Cada vez que quieras publicar:**

```bash
flutter build web --release
firebase deploy
```

`firebase deploy` sube la app **y** las reglas. Para subir solo una parte:

```bash
firebase deploy --only hosting
firebase deploy --only firestore:rules
```

La app queda en `https://cafeteria-sistema-123ef.web.app`.

Notas:
- Las reglas que se publican son las de este repositorio: si las cambias a mano
  en la consola, el siguiente `firebase deploy` las sobrescribe. Edita siempre
  `firestore.rules`.
- **Dominio propio**: en Hosting → *Agregar dominio personalizado*, y después
  añádelo en Authentication → Configuración → *Dominios autorizados*; sin eso el
  inicio de sesión falla en el dominio nuevo.
- Los archivos que cambian en cada versión (`index.html`, `main.dart.js`,
  service worker) se sirven sin caché para que las actualizaciones lleguen.

## Uso sin conexión

La persistencia de Firestore está activada (por defecto en web viene apagada), y
la versión publicada guarda la app en el navegador después de la primera visita.

Sin internet se puede: abrir turno, escanear, cobrar (efectivo, tarjeta, mixto o
crédito con un cliente ya cargado) y cerrar turno. Aparece un aviso naranja y
las ventas se guardan en el equipo y se envían solas al volver la conexión.

Limitaciones:
- El equipo debe haber cargado los productos con internet al menos una vez.
- Sin conexión el stock y el crédito se validan contra lo último que ese equipo
  tenía guardado. Dos equipos vendiendo lo mismo sin internet pueden dejar el
  stock en negativo, o un cliente pasado de su límite, al sincronizar.
- Cancelar o editar una venta, registrar abonos y las pantallas de
  administración de productos, clientes y sucursales requieren internet.
- Recargar la página sin internet solo funciona en la versión publicada, no en
  `flutter run`.

## Estructura del proyecto

```
lib/
  main.dart               Arranque, Firebase, tema e idioma
  auth/                   Login y AuthGate (decide qué pantalla ve cada rol)
  register_screen.dart    Registro con código de invitación
  users/                  Inicio del vendedor
  admin/                  Panel de admin: estadísticas, productos, clientes,
                          usuarios, sucursales, historial de stock
  pos/                    Punto de venta: apertura, venta, pago, cierre, historial
  models/                 Producto, Cliente, Sucursal, carrito
  utils/                  Formato de pesos, cálculo de pago, resumen de ventas,
                          escrituras sin conexión, movimientos de stock
test/                     Pruebas de dinero, reportes, cobro y diseño en tablet
firestore.rules           Reglas de seguridad
firebase.json             Hosting + reglas
```

Colecciones de Firestore: `usuarios`, `sucursales`, `productos`, `clientes`,
`ventas`, `turnos`, `movimientosStock` y `config`.

## Estado y pendientes conocidos

- La cancelación/edición de ventas y los abonos no funcionan sin conexión.
- No hay verificación de aplicaciones (App Check) activada.
- El diseño en tablet solo está verificado con pruebas automáticas del diálogo
  de cobro y revisión de código; conviene probarlo en un dispositivo real.
