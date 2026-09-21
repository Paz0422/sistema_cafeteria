import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cuenta_abierta.dart';
import '../models/producto.dart';
import '../models/item_carrito.dart';
import '../utils/calculo_pago.dart';
import '../utils/escritura_offline.dart';
import '../utils/formato.dart';
import '../utils/busqueda_productos.dart';
import '../utils/cuentas_guardadas.dart';
import 'dialogo_ajuste_stock.dart';
import 'dialogo_pago.dart';
import 'historial_ventas_screen.dart';
import '../theme/marca.dart';
import '../widgets/logo_fusion.dart';
import '../widgets/premium.dart';

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
  final String sucursalId;
  final String grupoClientesId;
  final String vendedorNombre;
  final int montoInicial;
  final bool esAdmin;
  final bool mostrarAppBar;

  const VentaScreen({
    super.key,
    required this.turnoId,
    required this.sucursalId,
    required this.grupoClientesId,
    required this.vendedorNombre,
    required this.montoInicial,
    this.esAdmin = false,
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

  // Catálogo completo escuchado en vivo. Sirve para buscar códigos de barras
  // y ver el stock actual sin depender de la red (la caché local lo mantiene
  // aun sin internet), y sus metadatos dicen si hay conexión con el servidor.
  Map<String, Producto> _catalogo = {};
  bool _enLinea = true;

  // Al recuperar cuentas guardadas, sus productos traen los precios de cuando
  // se guardaron: en cuanto llega el catálogo se actualizan a los vigentes.
  bool _refrescarPendiente = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _suscripcion;

  @override
  void initState() {
    super.initState();
    _suscripcion = FirebaseFirestore.instance
        .collection('productos')
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          if (!mounted) return;
          setState(() {
            _catalogo = {
              for (final doc in snapshot.docs) doc.id: Producto.fromDoc(doc),
            };
            _enLinea = !snapshot.metadata.isFromCache;
          });
          _refrescarConCatalogo();
        }, onError: (_) {});
    _restaurarCuentas();
  }

  /// Guarda en este equipo las cuentas abiertas, para no perderlas si se corta
  /// la luz o se cierra la página. Se llama después de cada cambio.
  void _persistir() {
    guardarCuentas(
      widget.turnoId,
      cuentas: _cuentas,
      indiceActivo: _cuentaActivaIndice,
      contador: _contadorCuentas,
    ).catchError((_) {});
  }

  /// Recupera las cuentas que quedaron abiertas si el turno se interrumpió.
  Future<void> _restaurarCuentas() async {
    final guardadas = await cargarCuentas(widget.turnoId);
    if (guardadas == null || !mounted) return;
    // Si ya se empezó a vender en esta pantalla no se pisa lo nuevo.
    if (_cuentas.length != 1 || _cuentas.first.carrito.isNotEmpty) return;

    setState(() {
      _cuentas
        ..clear()
        ..addAll(guardadas.cuentas);
      _cuentaActivaIndice = guardadas.indiceActivo;
      _contadorCuentas = guardadas.contador;
      _refrescarPendiente = true;
    });
    _refrescarConCatalogo();

    final productos = guardadas.cuentas.fold<int>(
      0,
      (suma, c) => suma + c.carrito.length,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Se recuperaron ${guardadas.cuentas.length} cuenta(s) abiertas '
          'con $productos producto(s).',
        ),
      ),
    );
  }

  void _refrescarConCatalogo() {
    if (!_refrescarPendiente || _catalogo.isEmpty || !mounted) return;
    setState(() {
      for (final cuenta in _cuentas) {
        for (var i = 0; i < cuenta.carrito.length; i++) {
          final fresco = _catalogo[cuenta.carrito[i].producto.id];
          if (fresco == null) continue;
          cuenta.carrito[i] = ItemCarrito(
            producto: fresco,
            cantidad: cuenta.carrito[i].cantidad,
          );
        }
      }
      _ultimoItem = null;
      _refrescarPendiente = false;
    });
    _persistir();
  }

  int _stockDe(Producto producto) =>
      (_catalogo[producto.id] ?? producto).stockEn(widget.sucursalId);

  Producto? _productoEnCatalogo(String codigo) {
    for (final producto in _catalogo.values) {
      if (producto.codigoBarras == codigo) return producto;
    }
    return null;
  }

  List<ItemCarrito> get _carrito => _cuentas[_cuentaActivaIndice].carrito;

  int get _total => _carrito.fold(0, (suma, item) => suma + item.subtotal);

  int get _ahorroTotal => _carrito.fold(0, (suma, item) => suma + item.ahorro);

  void _cambiarCuenta(int indice) {
    setState(() {
      _cuentaActivaIndice = indice;
      _ultimoItem = null;
    });
    _persistir();
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
    _persistir();
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
    _persistir();
  }

  /// Lo que se escribió en el campo, si no es un código de barras del
  /// catálogo: sirve para sugerir productos por nombre.
  List<Producto> get _sugerencias {
    final texto = _codigoController.text.trim();
    if (texto.length < 2 || _productoEnCatalogo(texto) != null) return const [];
    return buscarProductosPorNombre(_catalogo.values, texto, maximo: 6);
  }

  /// Enter en el campo: primero como código de barras (lo que hace el
  /// escáner) y, si no es un código, como nombre (agrega el primer resultado,
  /// el mismo que se ve primero en las sugerencias).
  Future<void> _buscarYAgregar(String texto) async {
    final entrada = texto.trim();
    if (entrada.isEmpty) return;

    setState(() => _buscando = true);
    try {
      var producto = _productoEnCatalogo(entrada);
      if (producto == null && entrada.contains(RegExp(r'[A-Za-zÁ-ú]'))) {
        producto = buscarProductosPorNombre(
          _catalogo.values,
          entrada,
          maximo: 1,
        ).firstOrNull;
      }
      if (producto == null) {
        final resultado = await FirebaseFirestore.instance
            .collection('productos')
            .where('codigoBarras', isEqualTo: entrada)
            .limit(1)
            .get();
        if (resultado.docs.isNotEmpty) {
          producto = Producto.fromDoc(resultado.docs.first);
        }
      }

      if (producto == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se encontró ningún producto con "$entrada"'),
            ),
          );
        }
        return;
      }

      await _agregarProducto(producto);
    } finally {
      _codigoController.clear();
      if (mounted) setState(() => _buscando = false);
      _codigoFocus.requestFocus();
    }
  }

  Future<void> _elegirSugerencia(Producto producto) async {
    _codigoController.clear();
    setState(() {});
    await _agregarProducto(producto);
    if (mounted) _codigoFocus.requestFocus();
  }

  /// Suma una unidad de [producto] al carrito. Si no alcanza el stock,
  /// ofrece agregarle stock ahí mismo en vez de obligar a salir a buscarlo.
  Future<void> _agregarProducto(Producto producto) async {
    var indice = _carrito.indexWhere((item) => item.producto.id == producto.id);
    final cantidadEnCarrito = indice >= 0 ? _carrito[indice].cantidad : 0;

    if (producto.controlaStock && cantidadEnCarrito + 1 > _stockDe(producto)) {
      final alcanza = await _ofrecerAgregarStock(
        producto,
        necesario: cantidadEnCarrito + 1,
      );
      if (!alcanza || !mounted) return;
      // El carrito pudo cambiar mientras estaba abierto el diálogo.
      indice = _carrito.indexWhere((item) => item.producto.id == producto.id);
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
    _persistir();
  }

  /// Pregunta si se quiere agregar stock a un producto que no alcanza para lo
  /// que se está vendiendo. Devuelve `true` si con lo agregado ya alcanza.
  Future<bool> _ofrecerAgregarStock(
    Producto producto, {
    required int necesario,
  }) async {
    final disponible = _stockDe(producto);
    final agregado = await showDialog<int>(
      context: context,
      builder: (context) => DialogoAjusteStock(
        sucursalId: widget.sucursalId,
        usuarioNombre: widget.vendedorNombre,
        producto: producto,
        aviso: disponible <= 0
            ? '"${producto.nombre}" no tiene stock en esta sucursal. '
                  '¿Quieres agregarle?'
            : 'De "${producto.nombre}" solo quedan $disponible y hacen falta '
                  '$necesario. ¿Quieres agregarle stock?',
      ),
    );
    if (agregado == null || !mounted) return false;

    if (disponible + agregado < necesario) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Con lo que agregaste aún no alcanza para ${producto.nombre}. '
            'Disponible: ${disponible + agregado}',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _cambiarCantidad(int indice, int delta) async {
    final item = _carrito[indice];

    if (delta > 0 &&
        item.producto.controlaStock &&
        item.cantidad + 1 > _stockDe(item.producto)) {
      final alcanza = await _ofrecerAgregarStock(
        item.producto,
        necesario: item.cantidad + 1,
      );
      if (!alcanza || !mounted) return;
    }

    // El carrito pudo cambiar mientras estaba abierto el diálogo.
    final actual = _carrito.indexOf(item);
    if (actual == -1) return;

    setState(() {
      final nuevaCantidad = item.cantidad + delta;
      if (nuevaCantidad <= 0) {
        _carrito.removeAt(actual);
      } else {
        item.cantidad = nuevaCantidad;
      }
    });
    _persistir();
  }

  void _quitarDelCarrito(ItemCarrito item) {
    setState(() {
      _carrito.remove(item);
      if (_ultimoItem == item) _ultimoItem = null;
    });
    _persistir();
    _codigoFocus.requestFocus();
  }

  void _sumarUltimoProducto() {
    final item = _ultimoItem;
    if (item == null) return;

    final indice = _carrito.indexOf(item);
    if (indice == -1) return;

    _cambiarCantidad(indice, 1);
  }

  Map<String, dynamic> _datosVenta(ResultadoPago resultado) {
    return {
      'fecha': FieldValue.serverTimestamp(),
      'turnoId': widget.turnoId,
      'sucursalId': widget.sucursalId,
      'total': _total,
      'metodoPago': resultado.metodo.name,
      'vuelto': resultado.vuelto,
      'montoEfectivo': resultado.montoEfectivo,
      'vendedorUid': FirebaseAuth.instance.currentUser?.uid,
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
    };
  }

  /// Devuelve `true` si el servidor confirmó la venta, o `false` si quedó
  /// guardada en el dispositivo esperando sincronizarse.
  Future<bool> _registrarVenta(ResultadoPago resultado) async {
    if (_enLinea) {
      try {
        await _registrarVentaEnLinea(resultado);
        return true;
      } on FirebaseException catch (e) {
        // Si la conexión se cayó justo ahora la transacción no se aplicó, así
        // que es seguro reintentar por la vía sin conexión.
        if (e.code != 'unavailable') rethrow;
      }
    }
    return _registrarVentaSinConexion(resultado);
  }

  // Las transacciones necesitan hablar con el servidor, así que sin internet
  // se usa un lote de escrituras: Firestore lo guarda en el dispositivo y lo
  // envía solo al volver la conexión. El stock y la deuda se ajustan con
  // increment() (suma/resta relativa) para no pisar ventas de otros equipos.
  // A cambio, la validación se hace contra lo último que el equipo tenía en
  // caché: dos equipos vendiendo sin conexión el mismo producto podrían dejar
  // el stock en negativo al sincronizar.
  Future<bool> _registrarVentaSinConexion(ResultadoPago resultado) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    for (final item in _carrito.where((i) => i.producto.controlaStock)) {
      final stockActual = _stockDe(item.producto);
      if (stockActual < item.cantidad) {
        throw _StockInsuficiente(item.producto.nombre, stockActual);
      }
      batch.update(firestore.collection('productos').doc(item.producto.id), {
        'stockPorSucursal.${widget.sucursalId}': FieldValue.increment(
          -item.cantidad,
        ),
      });
    }

    final cliente = resultado.cliente;
    if (resultado.metodo == MetodoPago.credito && cliente != null) {
      if (cliente.deuda + _total > cliente.limiteCredito) {
        throw _LimiteCreditoExcedido(
          cliente.nombre,
          cliente.limiteCredito - cliente.deuda,
        );
      }
      batch.update(firestore.collection('clientes').doc(cliente.id), {
        'deuda': FieldValue.increment(_total),
      });
    }

    batch.set(firestore.collection('ventas').doc(), _datosVenta(resultado));

    final mensajero = ScaffoldMessenger.of(context);
    return esperarConfirmacion(
      batch.commit(),
      siFallaDespues: (error) => mensajero.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(
            'Una venta hecha sin conexión fue rechazada al sincronizar y no '
            'quedó registrada: $error',
          ),
        ),
      ),
    );
  }

  Future<void> _registrarVentaEnLinea(ResultadoPago resultado) async {
    final firestore = FirebaseFirestore.instance;

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
        final stockPorSucursal =
            lecturas[i].data()?['stockPorSucursal'] as Map<String, dynamic>?;
        final stockActual =
            (stockPorSucursal?[widget.sucursalId] as num?)?.toInt() ?? 0;

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
        (ref, stock) => transaccion.update(ref, {
          'stockPorSucursal.${widget.sucursalId}': stock,
        }),
      );

      if (clienteRef != null) {
        transaccion.update(clienteRef, {'deuda': nuevaDeuda});
      }

      transaccion.set(
        firestore.collection('ventas').doc(),
        _datosVenta(resultado),
      );
    });
  }

  Future<void> _cobrar() async {
    final resultado = await showDialog<ResultadoPago>(
      context: context,
      builder: (context) =>
          DialogoPago(total: _total, grupoClientesId: widget.grupoClientesId),
    );

    if (resultado == null || !mounted) return;

    setState(() => _registrando = true);
    bool confirmada;
    try {
      confirmada = await _registrarVenta(resultado);
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

    // Aviso que no interrumpe: la venta sigue sin apretar "aceptar". El vuelto
    // queda a la vista unos segundos para entregarlo.
    final detalle =
        switch (resultado.metodo) {
          MetodoPago.tarjeta =>
            'Pago con tarjeta por ${formatearPesos(_total)}',
          MetodoPago.credito =>
            'A crédito de ${resultado.cliente?.nombre}: ${formatearPesos(_total)}',
          MetodoPago.efectivo ||
          MetodoPago.mixto => 'Vuelto: ${formatearPesos(resultado.vuelto)}',
        } +
        (confirmada
            ? ''
            : '\nSin conexión: se enviará sola al volver internet.');
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Marca.exito),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Venta registrada',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(detalle),
                  ],
                ),
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
    _persistir();
    _codigoFocus.requestFocus();
  }

  void _mostrarHistorial({bool paraCambio = false}) {
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
            sucursalId: widget.sucursalId,
            vendedorNombre: widget.vendedorNombre,
            esAdmin: widget.esAdmin,
            mostrarAppBar: false,
            ayuda: paraCambio
                ? 'Toca la venta y luego "Cambiar producto".'
                : null,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
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
        body: FondoFusion(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    if (!_enLinea)
                      Container(
                        width: double.infinity,
                        color: Marca.avisoFondo,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_off,
                              color: Marca.avisoTexto,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sin conexión: puedes seguir vendiendo. Las '
                                'ventas se guardan en este equipo y se envían '
                                'solas al volver internet.',
                                style: const TextStyle(color: Marca.avisoTexto),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                          labelText: 'Escanea el código o busca por nombre',
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
                        onChanged: (_) => setState(() {}),
                        onSubmitted: _buscarYAgregar,
                      ),
                    ),
                    if (_sugerencias.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _ListaSugerencias(
                          productos: _sugerencias,
                          stockDe: _stockDe,
                          onElegir: _elegirSugerencia,
                        ),
                      ),
                    Expanded(
                      child: _carrito.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MascotaFusion(tamano: 150),
                                  SizedBox(height: 12),
                                  Text(
                                    'Escanea un producto para comenzar',
                                    style: TextStyle(color: Marca.textoSuave),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _carrito.length,
                              itemBuilder: (context, indice) {
                                final item = _carrito[indice];
                                return _FilaCarrito(
                                  item: item,
                                  stockRestante: item.producto.controlaStock
                                      ? _stockDe(item.producto) - item.cantidad
                                      : null,
                                  onMenos: () => _cambiarCantidad(indice, -1),
                                  onMas: () => _cambiarCantidad(indice, 1),
                                  onQuitar: () => _quitarDelCarrito(item),
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
                decoration: const BoxDecoration(
                  color: Marca.carbon,
                  border: Border(left: BorderSide(color: Marca.borde)),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: Marca.textoSuave,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_ahorroTotal > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Ahorro por promociones: ${formatearPesos(_ahorroTotal)}',
                          style: const TextStyle(color: Marca.exito),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: Marca.degradadoTarjeta,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Marca.dorado.withValues(alpha: 0.45),
                        ),
                        boxShadow: Marca.brilloDorado,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              color: Marca.textoSobreOscuro,
                              fontSize: 12,
                              letterSpacing: 1.4,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: NumeroAnimado(
                              valor: _total,
                              formato: formatearPesos,
                              duracion: const Duration(milliseconds: 350),
                              estilo: const TextStyle(
                                color: Marca.dorado,
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: () => _mostrarHistorial(paraCambio: true),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Cambiar un producto'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: activa ? Marca.doradoSuave : Marca.superficie,
          border: Border.all(
            color: activa ? Marca.dorado : Marca.borde,
            width: activa ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
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
                    fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                    color: activa ? Marca.doradoClaro : Marca.texto,
                  ),
                ),
                if (total > 0)
                  Text(
                    formatearPesos(total),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Marca.textoSuave,
                    ),
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

/// Resultados de buscar por nombre. Tocar uno lo agrega a la venta; los que
/// no tienen stock avisan y ofrecen agregarlo.
class _ListaSugerencias extends StatelessWidget {
  final List<Producto> productos;
  final int Function(Producto) stockDe;
  final ValueChanged<Producto> onElegir;

  const _ListaSugerencias({
    required this.productos,
    required this.stockDe,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Marca.superficieAlta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Marca.dorado.withValues(alpha: 0.35)),
        boxShadow: Marca.sombraSuave,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < productos.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              Builder(
                builder: (context) {
                  final producto = productos[i];
                  final stock = stockDe(producto);
                  final sinStock = producto.controlaStock && stock <= 0;
                  return InkWell(
                    onTap: () => onElegir(producto),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              producto.nombre,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatearPesos(producto.precio),
                            style: const TextStyle(
                              color: Marca.textoSobreOscuro,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (producto.controlaStock)
                            Text(
                              sinStock ? 'Sin stock' : 'Stock: $stock',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sinStock
                                    ? Marca.peligro
                                    : stock <= 5
                                    ? Marca.alerta
                                    : Marca.textoSuave,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un producto del carrito: cantidad con − y +, subtotal y un botón claro
/// para quitarlo entero.
class _FilaCarrito extends StatelessWidget {
  final ItemCarrito item;

  /// Unidades que quedarían en stock después de esta venta (null si el
  /// producto no controla stock).
  final int? stockRestante;
  final VoidCallback onMenos;
  final VoidCallback onMas;
  final VoidCallback onQuitar;

  const _FilaCarrito({
    required this.item,
    required this.stockRestante,
    required this.onMenos,
    required this.onMas,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final producto = item.producto;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    producto.tienePromo
                        ? 'Promo: ${producto.promoCantidad} x '
                              '${formatearPesos(producto.promoPrecioPack)} · '
                              '${formatearPesos(producto.precio)} c/u'
                        : '${formatearPesos(producto.precio)} c/u',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Marca.textoSuave,
                    ),
                  ),
                  if (stockRestante != null)
                    Text(
                      'Quedan $stockRestante disponibles',
                      style: TextStyle(
                        fontSize: 12,
                        color: stockRestante! <= 0
                            ? Marca.peligro
                            : Marca.textoSuave,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Marca.carbon,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Marca.borde),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Quitar una unidad',
                    icon: const Icon(Icons.remove),
                    onPressed: onMenos,
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${item.cantidad}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Agregar una unidad',
                    icon: const Icon(Icons.add),
                    onPressed: onMas,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 86,
              child: Text(
                formatearPesos(item.subtotal),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Quitar del carrito',
              onPressed: onQuitar,
              style: IconButton.styleFrom(
                foregroundColor: Marca.peligro,
                backgroundColor: Marca.peligro.withValues(alpha: 0.12),
              ),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
