import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../theme/marca.dart';
import '../utils/cambio_venta.dart';
import '../utils/formato.dart';
import '../utils/registrar_cambio.dart';
import 'seleccionar_producto_dialog.dart';

/// Cambio de producto sobre una venta ya hecha: la persona devuelve algo y se
/// lleva otra cosa. Calcula solo si hay que cobrar o devolver la diferencia y
/// deja todo registrado en el turno. Devuelve `true` si se hizo el cambio.
class DialogoCambio extends StatefulWidget {
  final String ventaId;
  final String turnoId;
  final String sucursalId;
  final String vendedorNombre;

  /// Cómo se pagó la venta original (efectivo, tarjeta, mixto o crédito).
  final String metodoOriginal;
  final String? clienteId;
  final String? clienteNombre;

  /// Los productos que la venta tiene hoy (ya con cambios anteriores).
  final List<ItemVenta> items;

  /// Se puede reemplazar en pruebas: cómo se elige el producto nuevo y cómo se
  /// guarda el cambio.
  final Future<Producto?> Function(BuildContext context)? elegirProducto;
  final Future<void> Function(
    CalculoCambio calculo,
    MedioDiferencia? medio,
    int efectivoRecibido,
  )?
  guardar;

  const DialogoCambio({
    super.key,
    required this.ventaId,
    required this.turnoId,
    required this.sucursalId,
    required this.vendedorNombre,
    required this.metodoOriginal,
    required this.items,
    this.clienteId,
    this.clienteNombre,
    this.elegirProducto,
    this.guardar,
  });

  @override
  State<DialogoCambio> createState() => _DialogoCambioState();
}

class _DialogoCambioState extends State<DialogoCambio> {
  late ItemVenta _item = widget.items.first;
  int _unidades = 1;
  Producto? _nuevo;
  MedioDiferencia? _medio;
  final _efectivoController = TextEditingController();
  bool _guardando = false;
  String? _error;

  CalculoCambio? get _calculo => _nuevo == null
      ? null
      : CalculoCambio(
          itemDevuelto: _item,
          unidades: _unidades,
          productoNuevo: _nuevo!,
        );

  int get _diferencia => _calculo?.diferencia ?? 0;

  List<MedioDiferencia> get _medios => mediosPermitidos(
    metodoOriginal: widget.metodoOriginal,
    diferencia: _diferencia,
  );

  int get _efectivoRecibido => desformatearPesos(_efectivoController.text);

  bool get _cobraEnEfectivo =>
      _medio == MedioDiferencia.efectivo && _diferencia > 0;

  bool get _puedeConfirmar {
    if (_calculo == null || _guardando) return false;
    if (_diferencia == 0) return true;
    if (_medio == null) return false;
    if (_cobraEnEfectivo) return _efectivoRecibido >= _diferencia;
    return true;
  }

  @override
  void dispose() {
    _efectivoController.dispose();
    super.dispose();
  }

  Future<void> _elegirNuevo() async {
    final producto =
        await (widget.elegirProducto?.call(context) ??
            showDialog<Producto>(
              context: context,
              builder: (context) =>
                  SeleccionarProductoDialog(sucursalId: widget.sucursalId),
            ));
    if (producto == null || !mounted) return;
    setState(() {
      _nuevo = producto;
      _error = null;
      _ajustarMedio();
    });
  }

  /// Deja elegido un medio válido para la diferencia actual.
  void _ajustarMedio() {
    final medios = _medios;
    if (medios.isEmpty) {
      _medio = null;
    } else if (!medios.contains(_medio)) {
      _medio = medios.first;
    }
  }

  Future<void> _confirmar() async {
    final calculo = _calculo;
    if (calculo == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final medio = _diferencia == 0 ? null : _medio;
      if (widget.guardar != null) {
        await widget.guardar!(calculo, medio, _efectivoRecibido);
      } else {
        await registrarCambio(
          calculo: calculo,
          medio: medio,
          efectivoRecibido: _efectivoRecibido,
          ventaOriginalId: widget.ventaId,
          turnoId: widget.turnoId,
          sucursalId: widget.sucursalId,
          vendedorNombre: widget.vendedorNombre,
          clienteId: widget.clienteId,
          clienteNombre: widget.clienteNombre,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on StockInsuficienteEnCambio catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'No hay stock suficiente de ${e.nombre}. Disponible: '
              '${e.disponible}',
        );
      }
    } on LimiteCreditoEnCambio catch (e) {
      if (mounted) {
        setState(
          () => _error =
              '${e.nombre} no tiene crédito suficiente para esta diferencia '
              '(disponible: ${formatearPesos(e.disponible)}).',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo hacer el cambio: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calculo = _calculo;
    final diferencia = _diferencia;

    return AlertDialog(
      title: const Text('Cambio de producto'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Etiqueta('El cliente devuelve'),
              if (widget.items.length == 1)
                Text(
                  _item.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                DropdownButtonFormField<ItemVenta>(
                  initialValue: _item,
                  isExpanded: true,
                  items: [
                    for (final i in widget.items)
                      DropdownMenuItem(
                        value: i,
                        child: Text('${i.nombre} (x${i.cantidad})'),
                      ),
                  ],
                  onChanged: (valor) {
                    if (valor == null) return;
                    setState(() {
                      _item = valor;
                      _unidades = 1;
                      _ajustarMedio();
                    });
                  },
                ),
              if (_item.cantidad > 1) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Unidades a cambiar:'),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Menos',
                      onPressed: _unidades > 1
                          ? () => setState(() {
                              _unidades--;
                              _ajustarMedio();
                            })
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$_unidades',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Más',
                      onPressed: _unidades < _item.cantidad
                          ? () => setState(() {
                              _unidades++;
                              _ajustarMedio();
                            })
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    Text(
                      'de ${_item.cantidad}',
                      style: const TextStyle(color: Marca.textoSuave),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const _Etiqueta('Se lleva'),
              OutlinedButton.icon(
                onPressed: _guardando ? null : _elegirNuevo,
                icon: const Icon(Icons.search),
                label: Text(
                  _nuevo == null
                      ? 'Elegir producto'
                      : '${_nuevo!.nombre} · ${formatearPesos(_nuevo!.precio)}',
                ),
              ),
              if (calculo != null) ...[
                const SizedBox(height: 16),
                _ResumenDiferencia(diferencia: diferencia),
                if (diferencia != 0) ...[
                  const SizedBox(height: 14),
                  _Etiqueta(diferencia > 0 ? 'Cobrar en' : 'Devolver en'),
                  if (_medios.length == 1)
                    Text(
                      _medios.first.etiqueta,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    )
                  else
                    SegmentedButton<MedioDiferencia>(
                      segments: [
                        for (final m in _medios)
                          ButtonSegment(value: m, label: Text(m.etiqueta)),
                      ],
                      selected: {?_medio},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _medio = s.first),
                    ),
                  if (_cobraEnEfectivo) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _efectivoController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      inputFormatters: [InputFormatoMiles()],
                      decoration: const InputDecoration(
                        labelText: 'Monto recibido',
                        prefixText: '\$ ',
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _puedeConfirmar ? _confirmar() : null,
                    ),
                    if (_efectivoRecibido > diferencia)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Vuelto: ${formatearPesos(_efectivoRecibido - diferencia)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Marca.exito,
                          ),
                        ),
                      ),
                  ],
                  if (_medio == MedioDiferencia.deuda)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        diferencia > 0
                            ? 'Se suma a lo que debe ${widget.clienteNombre ?? 'el cliente'}.'
                            : 'Se le descuenta a ${widget.clienteNombre ?? 'el cliente'} de su deuda.',
                        style: const TextStyle(
                          color: Marca.textoSuave,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Marca.peligro),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _puedeConfirmar ? _confirmar : null,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmar cambio'),
        ),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;

  const _Etiqueta(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 0.4,
        color: Marca.textoSuave,
      ),
    ),
  );
}

/// Lo importante del cambio en grande: cobrar, devolver o nada.
class _ResumenDiferencia extends StatelessWidget {
  final int diferencia;

  const _ResumenDiferencia({required this.diferencia});

  @override
  Widget build(BuildContext context) {
    final (titulo, monto, color) = diferencia > 0
        ? ('Cobrar la diferencia', formatearPesos(diferencia), Marca.dorado)
        : diferencia < 0
        ? ('Devolver al cliente', formatearPesos(-diferencia), Marca.exito)
        : ('Mismo precio', 'Sin diferencia', Marca.textoSobreOscuro);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontSize: 12, color: Marca.textoSuave),
          ),
          Text(
            monto,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
