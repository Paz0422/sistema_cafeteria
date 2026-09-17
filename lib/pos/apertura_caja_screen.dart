import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/formato.dart';
import 'pos_screen.dart';

class AperturaCajaScreen extends StatefulWidget {
  final String vendedorNombre;
  final String sucursalId;
  final bool esAdmin;

  const AperturaCajaScreen({
    super.key,
    required this.vendedorNombre,
    required this.sucursalId,
    this.esAdmin = false,
  });

  @override
  State<AperturaCajaScreen> createState() => _AperturaCajaScreenState();
}

class _AperturaCajaScreenState extends State<AperturaCajaScreen> {
  final _billetesController = TextEditingController();
  final _monedasController = TextEditingController();
  bool _guardando = false;

  int get _billetes => desformatearPesos(_billetesController.text);

  int get _monedas => desformatearPesos(_monedasController.text);

  int get _totalInicial => _billetes + _monedas;

  Future<void> _abrirCaja() async {
    setState(() => _guardando = true);
    try {
      final sucursalDoc = await FirebaseFirestore.instance
          .collection('sucursales')
          .doc(widget.sucursalId)
          .get();
      final grupoClientesId =
          (sucursalDoc.data()?['grupoClientesId'] as String?)?.isNotEmpty ==
              true
          ? sucursalDoc.data()!['grupoClientesId'] as String
          : widget.sucursalId;

      final vendedor = FirebaseAuth.instance.currentUser;
      final turnoRef = await FirebaseFirestore.instance
          .collection('turnos')
          .add({
            'estado': 'abierto',
            'sucursalId': widget.sucursalId,
            'fechaApertura': FieldValue.serverTimestamp(),
            'vendedorUid': vendedor?.uid,
            'vendedorNombre': widget.vendedorNombre,
            'montoInicial': _totalInicial,
            'billetesApertura': _billetes,
            'monedasApertura': _monedas,
          });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PosScreen(
              turnoId: turnoRef.id,
              sucursalId: widget.sucursalId,
              grupoClientesId: grupoClientesId,
              vendedorNombre: widget.vendedorNombre,
              montoInicial: _totalInicial,
              esAdmin: widget.esAdmin,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo abrir la caja: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _billetesController.dispose();
    _monedasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apertura de caja')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Indica cuánto dinero hay en caja antes de empezar a vender',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _billetesController,
                keyboardType: TextInputType.number,
                inputFormatters: [InputFormatoMiles()],
                decoration: const InputDecoration(
                  labelText: 'Total en billetes',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _monedasController,
                keyboardType: TextInputType.number,
                inputFormatters: [InputFormatoMiles()],
                decoration: const InputDecoration(
                  labelText: 'Total en monedas',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const Divider(height: 32),
              Text(
                'Monto inicial en caja: ${formatearPesos(_totalInicial)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _guardando ? null : _abrirCaja,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.point_of_sale),
                label: const Text('Abrir caja'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
