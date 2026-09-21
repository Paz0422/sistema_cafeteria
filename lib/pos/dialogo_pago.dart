import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../utils/calculo_pago.dart';
import '../utils/formato.dart';
import 'seleccionar_cliente_dialog.dart';

class ResultadoPago {
  final MetodoPago metodo;
  final int vuelto;
  final int montoEfectivo;
  final Cliente? cliente;

  const ResultadoPago({
    required this.metodo,
    required this.vuelto,
    required this.montoEfectivo,
    this.cliente,
  });
}

class DialogoPago extends StatefulWidget {
  final int total;
  final String grupoClientesId;

  const DialogoPago({
    super.key,
    required this.total,
    required this.grupoClientesId,
  });

  @override
  State<DialogoPago> createState() => _DialogoPagoState();
}

class _DialogoPagoState extends State<DialogoPago> {
  MetodoPago _metodo = MetodoPago.efectivo;
  final _efectivoController = TextEditingController();
  final _tarjetaController = TextEditingController();
  Cliente? _cliente;

  // Toda la aritmética del cobro vive en CalculoPago (probada aparte).
  CalculoPago get _calculo => CalculoPago(
    metodo: _metodo,
    total: widget.total,
    efectivoIngresado: desformatearPesos(_efectivoController.text),
    tarjetaIngresada: desformatearPesos(_tarjetaController.text),
    cliente: _cliente,
  );

  int get _vuelto => _calculo.vuelto;

  bool get _puedeConfirmar => _calculo.puedeConfirmar;

  Future<void> _elegirCliente() async {
    final cliente = await showDialog<Cliente>(
      context: context,
      builder: (context) =>
          SeleccionarClienteDialog(grupoClientesId: widget.grupoClientesId),
    );
    if (cliente != null) setState(() => _cliente = cliente);
  }

  @override
  void dispose() {
    _efectivoController.dispose();
    _tarjetaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cobrar'),
      // Scroll: con el teclado en pantalla de una tablet en horizontal queda
      // poco alto y el contenido se desbordaba.
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total a pagar: ${formatearPesos(widget.total)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<MetodoPago>(
                segments: const [
                  ButtonSegment(
                    value: MetodoPago.efectivo,
                    label: Text('Efectivo'),
                    icon: Icon(Icons.payments),
                  ),
                  ButtonSegment(
                    value: MetodoPago.tarjeta,
                    label: Text('Tarjeta'),
                    icon: Icon(Icons.credit_card),
                  ),
                  ButtonSegment(
                    value: MetodoPago.mixto,
                    label: Text('Mixto'),
                    icon: Icon(Icons.sync_alt),
                  ),
                  ButtonSegment(
                    value: MetodoPago.credito,
                    label: Text('Crédito'),
                    icon: Icon(Icons.assignment_ind),
                  ),
                ],
                selected: {_metodo},
                onSelectionChanged: (seleccion) =>
                    setState(() => _metodo = seleccion.first),
              ),
              const SizedBox(height: 16),
              if (_metodo == MetodoPago.efectivo || _metodo == MetodoPago.mixto)
                TextField(
                  controller: _efectivoController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [InputFormatoMiles()],
                  decoration: const InputDecoration(
                    labelText: 'Monto en efectivo',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (_metodo == MetodoPago.mixto) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _tarjetaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [InputFormatoMiles()],
                  decoration: const InputDecoration(
                    labelText: 'Monto con tarjeta',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (_metodo == MetodoPago.tarjeta)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Se cobrará el total completo con tarjeta.'),
                ),
              if (_metodo == MetodoPago.credito) ...[
                Text(
                  _cliente == null
                      ? 'Elige a qué cliente se le da esta venta a crédito.'
                      : 'Cliente: ${_cliente!.nombre} · '
                            'Disponible: ${formatearPesos(_cliente!.creditoDisponible)}',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _elegirCliente,
                  icon: const Icon(Icons.person_search),
                  label: Text(_cliente == null ? 'Elegir cliente' : 'Cambiar'),
                ),
                if (_cliente != null && !_puedeConfirmar)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Esta venta supera el límite de crédito del cliente.',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              if (_metodo == MetodoPago.efectivo && _vuelto >= 0)
                Text(
                  'Vuelto: ${formatearPesos(_vuelto)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              if (_metodo == MetodoPago.mixto)
                Text(
                  _vuelto >= 0
                      ? 'Vuelto: ${formatearPesos(_vuelto)}'
                      : 'Falta: ${formatearPesos(-_vuelto)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _puedeConfirmar ? Colors.green[700] : Colors.red,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _puedeConfirmar
              ? () => Navigator.pop(
                  context,
                  ResultadoPago(
                    metodo: _metodo,
                    vuelto: _calculo.vueltoAEntregar,
                    montoEfectivo: _calculo.montoEfectivo,
                    cliente: _cliente,
                  ),
                )
              : null,
          child: const Text('Confirmar pago'),
        ),
      ],
    );
  }
}
