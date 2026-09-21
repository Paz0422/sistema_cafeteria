import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sucursal.dart';
import '../utils/formato.dart';
import 'apertura_caja_screen.dart';
import 'pos_screen.dart';
import '../theme/marca.dart';
import '../widgets/logo_fusion.dart';

/// Elige en qué sucursal se va a trabajar este turno y abre la caja ahí.
/// La usan tanto un vendedor normal (siempre puede elegir cualquier
/// sucursal, porque un mismo cajero puede trabajar en distintos locales
/// según el día) como el admin desde su "Panel vendedor".
class SelectorSucursalApertura extends StatefulWidget {
  final String nombreVendedor;
  final bool esAdmin;
  final String descripcion;
  final String textoBoton;

  const SelectorSucursalApertura({
    super.key,
    required this.nombreVendedor,
    this.esAdmin = false,
    this.descripcion = 'Elige en qué sucursal vas a trabajar hoy.',
    this.textoBoton = 'Abrir turno',
  });

  @override
  State<SelectorSucursalApertura> createState() =>
      _SelectorSucursalAperturaState();
}

class _SelectorSucursalAperturaState extends State<SelectorSucursalApertura> {
  String? _sucursalId;

  // Se crea una sola vez: si se creara dentro de build(), cada cambio en la
  // pantalla volvería a suscribirse.
  late Stream<QuerySnapshot<Map<String, dynamic>>> _sucursalesStream =
      FirebaseFirestore.instance.collection('sucursales').snapshots();

  // Turnos de esta persona que siguen abiertos (por ejemplo, tras un corte de
  // luz): en vez de abrir uno nuevo se retoma el que quedó a medias.
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _turnosAbiertos =
      FirebaseAuth.instance.currentUser == null
      ? null
      : FirebaseFirestore.instance
            .collection('turnos')
            .where(
              'vendedorUid',
              isEqualTo: FirebaseAuth.instance.currentUser!.uid,
            )
            .where('estado', isEqualTo: 'abierto')
            .snapshots();

  void _continuarTurno(
    QueryDocumentSnapshot<Map<String, dynamic>> turno,
    List<Sucursal> sucursales,
  ) {
    final datos = turno.data();
    final sucursalId = datos['sucursalId'] as String? ?? '';
    final sucursal = sucursales.where((s) => s.id == sucursalId).firstOrNull;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PosScreen(
          turnoId: turno.id,
          sucursalId: sucursalId,
          grupoClientesId: sucursal?.grupoClientes ?? sucursalId,
          vendedorNombre: widget.nombreVendedor,
          montoInicial: (datos['montoInicial'] as num?)?.toInt() ?? 0,
          esAdmin: widget.esAdmin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _sucursalesStream,
      builder: (context, snapshot) {
        // Sin esto, un error (por ejemplo, permisos) dejaba la pantalla
        // cargando para siempre sin decir por qué.
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Marca.peligro,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No se pudieron cargar las sucursales.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Marca.textoSuave,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() {
                      _sucursalesStream = FirebaseFirestore.instance
                          .collection('sucursales')
                          .snapshots();
                    }),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sucursales = snapshot.data!.docs.map(Sucursal.fromDoc).toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre));

        if (sucursales.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavía no hay ninguna sucursal creada. Pídele a un '
                'administrador que cree una antes de abrir turno.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final sucursalId =
            (_sucursalId != null && sucursales.any((s) => s.id == _sucursalId))
            ? _sucursalId!
            : sucursales.first.id;

        final tarjetaApertura = Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MascotaFusion(tamano: 130),
                const SizedBox(height: 16),
                Text(widget.descripcion, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: sucursalId,
                  decoration: const InputDecoration(
                    labelText: 'Sucursal',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final sucursal in sucursales)
                      DropdownMenuItem(
                        value: sucursal.id,
                        child: Text(sucursal.nombre),
                      ),
                  ],
                  onChanged: (valor) => setState(() => _sucursalId = valor),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AperturaCajaScreen(
                            vendedorNombre: widget.nombreVendedor,
                            sucursalId: sucursalId,
                            esAdmin: widget.esAdmin,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: Text(widget.textoBoton),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _turnosAbiertos,
          builder: (context, turnosSnap) {
            // Si no se pueden consultar los turnos, se sigue como si no
            // hubiera ninguno abierto: nunca debe impedir abrir uno.
            // Solo turnos de la sesión actual, aunque llegara otro por error.
            final miUid = FirebaseAuth.instance.currentUser?.uid;
            final abiertos =
                (turnosSnap.data?.docs ?? [])
                    .where((d) => d.data()['vendedorUid'] == miUid)
                    .toList()
                  ..sort((a, b) {
                    DateTime f(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                        (d.data()['fechaApertura'] as Timestamp?)?.toDate() ??
                        DateTime.now();
                    return f(b).compareTo(f(a));
                  });

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: abiertos.isEmpty
                      ? tarjetaApertura
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final turno in abiertos)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _TarjetaTurnoAbierto(
                                  datos: turno.data(),
                                  nombreSucursal:
                                      sucursales
                                          .where(
                                            (s) =>
                                                s.id ==
                                                turno.data()['sucursalId'],
                                          )
                                          .firstOrNull
                                          ?.nombre ??
                                      'Sucursal',
                                  onContinuar: () =>
                                      _continuarTurno(turno, sucursales),
                                ),
                              ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'Para abrir un turno nuevo, primero continúa '
                                'este y ciérralo desde "Cerrar turno".',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Marca.textoSuave,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Un turno que quedó abierto: muestra desde cuándo y con cuánta caja, y deja
/// retomarlo con las cuentas que se estaban atendiendo.
class _TarjetaTurnoAbierto extends StatelessWidget {
  final Map<String, dynamic> datos;
  final String nombreSucursal;
  final VoidCallback onContinuar;

  const _TarjetaTurnoAbierto({
    required this.datos,
    required this.nombreSucursal,
    required this.onContinuar,
  });

  @override
  Widget build(BuildContext context) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final apertura = (datos['fechaApertura'] as Timestamp?)?.toDate();
    final desde = apertura == null
        ? 'hace un momento'
        : '${dos(apertura.day)}/${dos(apertura.month)} '
              '${dos(apertura.hour)}:${dos(apertura.minute)}';
    final monto = (datos['montoInicial'] as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.history_toggle_off, color: Marca.dorado),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tienes un turno abierto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$nombreSucursal · desde $desde\n'
              'Abierto por ${datos['vendedorNombre'] ?? 'este usuario'}\n'
              'Caja inicial: ${formatearPesos(monto)}',
              style: const TextStyle(color: Marca.textoSobreOscuro),
            ),
            const SizedBox(height: 6),
            const Text(
              'Las cuentas que tenías abiertas en este equipo se recuperan '
              'al continuar.',
              style: TextStyle(color: Marca.textoSuave, fontSize: 12),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onContinuar,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Continuar turno'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
