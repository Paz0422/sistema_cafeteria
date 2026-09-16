import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cuenta_abierta.dart';
import '../models/producto.dart';
import '../models/item_carrito.dart';
import '../utils/formato.dart';
import 'dialogo_pago.dart';
import 'historial_ventas_screen.dart';

class _StockInsuficiente implements Exception {
  final String nombre;
  final int disponible;

  _StockInsuficiente(this.nombre, this.disponible);
}

class _LimiteCreditoExcedido implements Exception {
  final String nombre;
  final int disponible;

  _LimiteCreditoExcedido(this.nombre, this.disponible);
}

class VentaScreen extends StatefulWidget {
  final String turnoId;
  final String vendedorNombre;
  final int montoInicial;
  final bool mostrarAppBar;

  const VentaScreen({
    super.key,
    required this.turnoId,
    required this.vendedorNombre,
    required this.montoInicial,
    this.mostrarAppBar = true,
  });

  @override
  State<VentaScreen> createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final _codigoController = TextEditingController();
  final _codigoFocus = FocusNode();
  final List<CuentaAbierta> _cuentas = [
    CuentaAbierta(id: '0', nombre: 'Cuenta 1'),
  ];
  int _cuentaActivaIndice = 0;
  int _contadorCuentas = 1;
  bool _buscando = false;
  bool _registrando = false;
  ItemCarrito? _ultimoItem;

  List<ItemCarrito> get _carrito => _cuentas[_cuentaActivaIndice].carrito;

  int get _total => _carrito.fold(0, (suma, item) => suma + item.subtotal);

  int get _ahorroTotal => _carrito.fold(0, (suma, item) => suma + item.ahorro);

  void _cambiarCuenta(int indice) {
    setState(() {
      _cuentaActivaIndice = indice;
      _ultimoItem = null;
    });
    _codigoFocus.requestFocus();
  }

  void _nuevaCuenta() {
    _contadorCuentas++;
    setState(() {
      _cuentas.add(
        CuentaAbierta(
          id: '$_contadorCuentas-${DateTime.now().microsecondsSinceEpoch}',
          nombre: 'Cuenta $_contadorCuentas',
        ),
      );
      _cuentaActivaIndice = _cuentas.length - 1;
      _ultimoItem = null;
    });
    _codigoFocus.requestFocus();
  }

  Future<void> _cerrarCuenta(int indice) async {
    if (_cuentas[indice].carrito.isNotEmpty) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cerrar cuenta'),
          content: Text(
            '"${_cuentas[indice].nombre}" todavía tiene productos sin '
            'cobrar. ¿Cerrarla igual? Se perderá lo que tiene.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cerrar de todas formas'),
            ),
          ],
        ),
      );
      if (confirmado != true) return;
    }

    setState(() {
      _cuentas.removeAt(indice);
      if (_cuentas.isEmpty) {
        _contadorCuentas++;
        _cuentas.add(
          CuentaAbierta(id: '0-$_contadorCuentas', nombre: 'Cuenta 1'),
        );
        _cuentaActivaIndice = 0;
      } else if (_cuentaActivaIndice >= _cuentas.length) {
        _cuentaActivaIndice = _cuentas.length - 1;
      } else if (_cuentaActivaIndice > indice) {
        _cuentaActivaIndice--;
      }
      _ultimoItem = null;
    });
  }

  Future<void> _buscarYAgregar(String codigo) async {
    final codigoLimpio = codigo.trim();
    if (codigoLimpio.isEmpty) return;

    setState(() => _buscando = true);
    try {
      final resultado = await FirebaseFirestore.instance
          .collection('productos')
          .where('codigoBarras', isEqualTo: codigoLimpio)
          .limit(1)
          .get();

      if (resultado.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se encontró ningún producto con el código $codigoLimpio',
              ),
            ),
          );
        }
        return;
      }

      final producto = Producto.fromDoc(resultado.docs.first);
      final indice = _carrito.indexWhere(
        (item) => item.producto.id == producto.id,
      );
      final cantidadEnCarrito = indice >= 0 ? _carrito[indice].cantidad : 0;

      if (producto.controlaStock && cantidadEnCarrito + 1 > producto.stock) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sin stock suficiente de ${producto.nombre}. '
                'Disponible: ${producto.stock}',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        if (indice >= 0) {
          _carrito[indice].cantidad++;
          _ultimoItem = _carrito[indice];
        } else {
          final nuevoItem = ItemCarrito(producto: producto);
          _carrito.add(nuevoItem);
          _ultimoItem = nuevoItem;
        }
      });
    } finally {
      _codigoController.clear();
      setState(() => _buscando = false);
      _codigoFocus.requestFocus();
    }
  }

  void _cambiarCantidad(int indice, int delta) {
    final item = _carrito[indice];

    if (delta > 0 &&
        item.producto.controlaStock &&
        item.cantidad + 1 > item.producto.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sin stock suficiente de ${item.producto.nombre}. '
            'Disponible: ${item.producto.stock}',
          ),
        ),
      );
      return;
    }

    setState(() {
      final nuevaCantidad = item.cantidad + delta;
      if (nuevaCantidad <= 0) {
        _carrito.removeAt(indice);
      } else {
        item.cantidad = nuevaCantidad;
      }
    });
  }

  void _sumarUltimoProducto() {
    final item = _ultimoItem;
    if (item == null) return;

    final indice = _carrito.indexOf(item);
    if (indice == -1) return;

    _cambiarCantidad(indice, 1);
  }

  Future<void> _registrarVenta(ResultadoPago resultado) async {
    final firestore = FirebaseFirestore.instance;
    final vendedorUid = FirebaseAuth.instance.currentUser?.uid;

    final itemsConStock = _carrito
        .where((item) => item.producto.controlaStock)
        .toList();
    final refsStock = [
      for (final item in itemsConStock)
        firestore.collection('productos').doc(item.producto.id),
    ];
    final clienteRef =
        resultado.metodo == MetodoPago.credito && resultado.cliente != null
        ? firestore.collection('clientes').doc(resultado.cliente!.id)
        : null;

    await firestore.runTransaction((transaccion) async {
      // Todas las lecturas se piden en paralelo (en vez de una por una)
      // para que una venta con varios productos distintos no se demore
      // un round-trip de red por cada uno.
      final lecturas = await Future.wait([
        for (final ref in refsStock) transaccion.get(ref),
        if (clienteRef != null) transaccion.get(clienteRef),
      ]);

      final nuevosStocks = <DocumentReference<Map<String, dynamic>>, int>{};
      for (var i = 0; i < itemsConStock.length; i++) {
        final item = itemsConStock[i];
        final stockActual =
            (lecturas[i].data()?['stock'] as num?)?.toInt() ?? 0;

        if (stockActual < item.cantidad) {
          throw _StockInsuficiente(item.producto.nombre, stockActual);
        }
        nuevosStocks[refsStock[i]] = stockActual - item.cantidad;
      }

      int? nuevaDeuda;
      if (clienteRef != null) {
        final datosCliente = lecturas.last.data();
        final deudaActual = (datosCliente?['deuda'] as num?)?.toInt() ?? 0;
        final limiteCredito =
            (datosCliente?['limiteCredito'] as num?)?.toInt() ?? 0;
        nuevaDeuda = deudaActual + _total;

        if (nuevaDeuda > limiteCredito) {
          throw _LimiteCreditoExcedido(
            resultado.cliente!.nombre,
            limiteCredito - deudaActual,
          );
        }
      }

      nuevosStocks.forEach(
        (ref, stock) => transaccion.update(ref, {'stock': stock}),
      );

      if (clienteRef != null) {
        transaccion.update(clienteRef, {'deuda': nuevaDeuda});
      }

      transaccion.set(firestore.collection('ventas').doc(), {
        'fecha': FieldValue.serverTimestamp(),
        'turnoId': widget.turnoId,
        'total': _total,
        'metodoPago': resultado.metodo.name,
        'vuelto': resultado.vuelto,
        'montoEfectivo': resultado.montoEfectivo,
        'vendedorUid': vendedorUid,
        'vendedorNombre': widget.vendedorNombre,
        'clienteId': resultado.cliente?.id,
        'clienteNombre': resultado.cliente?.nombre,
        'items': _carrito
            .map(
              (item) => {
                'productoId': item.producto.id,
                'nombre': item.producto.nombre,
                'cantidad': item.cantidad,
                'precioUnitario': item.producto.precio,
                'subtotal': item.subtotal,
              },
            )
            .toList(),
      });
    });
  }

  Future<void> _cobrar() async {
    final resultado = await showDialog<ResultadoPago>(
      context: context,
      builder: (context) => DialogoPago(total: _total),
    );

    if (resultado == null || !mounted) return;

    setState(() => _registrando = true);
    try {
      await _registrarVenta(resultado);
    } on _StockInsuficiente catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sin stock suficiente de ${e.nombre}. Disponible: ${e.disponible}',
            ),
          ),
        );
      }
      return;
    } on _LimiteCreditoExcedido catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${e.nombre} ya no tiene crédito disponible para esta venta '
              '(disponible: ${formatearPesos(e.disponible)}).',
            ),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _registrando = false);
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => _DialogoAutoCierre(
        child: AlertDialog(
          title: const Text('Venta registrada'),
          content: Text(switch (resultado.metodo) {
            MetodoPago.tarjeta =>
              'Pago con tarjeta por ${formatearPesos(_total)}.',
            MetodoPago.credito =>
              'Venta a crédito de ${resultado.cliente?.nombre}: '
                  '${formatearPesos(_total)}.',
            MetodoPago.efectivo || MetodoPago.mixto =>
              'Vuelto a entregar: ${formatearPesos(resultado.vuelto)}',
          }),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );

    setState(() {
      if (_cuentas.length > 1) {
        final indiceCerrado = _cuentaActivaIndice;
        _cuentas.removeAt(indiceCerrado);
        _cuentaActivaIndice = indiceCerrado >= _cuentas.length
            ? _cuentas.length - 1
            : indiceCerrado;
      } else {
        _carrito.clear();
      }
      _ultimoItem = null;
    });
  }

  void _mostrarHistorial() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 480,
          height: 560,
          child: HistorialVentasScreen(
            turnoId: widget.turnoId,
            mostrarAppBar: false,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _codigoFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(LogicalKeyboardKey.add): _sumarUltimoProducto,
        LogicalKeySet(LogicalKeyboardKey.numpadAdd): _sumarUltimoProducto,
      },
      child: Scaffold(
        appBar: widget.mostrarAppBar
            ? AppBar(title: const Text('Realizar venta'))
            : null,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  SizedBox(
                    height: 58,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      children: [
                        for (var i = 0; i < _cuentas.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _PestanaCuenta(
                              cuenta: _cuentas[i],
                              activa: i == _cuentaActivaIndice,
                              onTap: () => _cambiarCuenta(i),
                              onCerrar: () => _cerrarCuenta(i),
                            ),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('Nueva cuenta'),
                          onPressed: _nuevaCuenta,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _codigoController,
                      focusNode: _codigoFocus,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Escanea o ingresa el código de barras',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        suffixIcon: _buscando
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onSubmitted: _buscarYAgregar,
                    ),
                  ),
                  Expanded(
                    child: _carrito.isEmpty
                        ? const Center(
                            child: Text('Escanea un producto para comenzar'),
                          )
                        : ListView.builder(
                            itemCount: _carrito.length,
                            itemBuilder: (context, indice) {
                              final item = _carrito[indice];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  leading: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => setState(
                                      () => _carrito.removeAt(indice),
                                    ),
                                  ),
                                  title: Text(item.producto.nombre),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.producto.tienePromo
                                            ? 'Promo: ${item.producto.promoCantidad} x '
                                                  '${formatearPesos(item.producto.promoPrecioPack)} · '
                                                  '${formatearPesos(item.producto.precio)} c/u'
                                            : '${formatearPesos(item.producto.precio)} c/u',
                                      ),
                                      if (item.producto.controlaStock)
                                        Text(
                                          'Quedan ${item.producto.stock - item.cantidad} disponibles',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                item.producto.stock -
                                                        item.cantidad <=
                                                    0
                                                ? Colors.red
                                                : Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        onPressed: () =>
                                            _cambiarCantidad(indice, -1),
                                      ),
                                      Text(
                                        '${item.cantidad}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        onPressed: () =>
                                            _cambiarCantidad(indice, 1),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          formatearPesos(item.subtotal),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            Container(
              width: 280,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  left: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _cuentas[_cuentaActivaIndice].nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Caja abierta con: ${formatearPesos(widget.montoInicial)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  if (_ahorroTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Ahorro por promociones: ${formatearPesos(_ahorroTotal)}',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                    ),
                  Text(
                    'Total: ${formatearPesos(_total)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _mostrarHistorial,
                    icon: const Icon(Icons.history),
                    label: const Text('Historial de ventas'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _carrito.isEmpty || _registrando
                        ? null
                        : _cobrar,
                    icon: _registrando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.point_of_sale),
                    label: const Text('Cobrar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PestanaCuenta extends StatelessWidget {
  final CuentaAbierta cuenta;
  final bool activa;
  final VoidCallback onTap;
  final VoidCallback onCerrar;

  const _PestanaCuenta({
    required this.cuenta,
    required this.activa,
    required this.onTap,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final total = cuenta.carrito.fold<int>(
      0,
      (suma, item) => suma + item.subtotal,
    );
    final colorPrimario = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: activa ? colorPrimario.withValues(alpha: 0.12) : null,
          border: Border.all(
            color: activa ? colorPrimario : Colors.grey.shade400,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cuenta.nombre,
                  style: TextStyle(
                    fontWeight: activa ? FontWeight.bold : FontWeight.normal,
                    color: activa ? colorPrimario : null,
                  ),
                ),
                if (total > 0)
                  Text(
                    formatearPesos(total),
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: onCerrar,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoAutoCierre extends StatefulWidget {
  final Widget child;

  const _DialogoAutoCierre({required this.child});

  @override
  State<_DialogoAutoCierre> createState() => _DialogoAutoCierreState();
}

class _DialogoAutoCierreState extends State<_DialogoAutoCierre> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
