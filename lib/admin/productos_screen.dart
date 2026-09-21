import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producto.dart';
import '../models/sucursal.dart';
import '../utils/escritura_offline.dart';
import '../utils/formato.dart';
import '../utils/movimientos_stock.dart';
import '../pos/dialogo_ajuste_stock.dart';
import 'historial_stock_screen.dart';
import '../theme/marca.dart';

/// Catálogo de productos.
///
/// El catálogo (nombre, código, precio y promo) es único para todas las
/// sucursales; lo único que cambia entre una y otra es el stock. Por eso el
/// admin lo ve sin elegir sucursal ([sucursalId] nulo): cada producto muestra
/// el stock de todas y el formulario deja editar el de cada una. Con
/// [sucursalId] (el punto de venta) se ve y se edita solo el de esa sucursal.
class ProductosScreen extends StatelessWidget {
  final String? sucursalId;
  final String usuarioNombre;
  final bool esAdmin;
  final bool mostrarAppBar;

  const ProductosScreen({
    super.key,
    required this.sucursalId,
    required this.usuarioNombre,
    this.esAdmin = false,
    this.mostrarAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mostrarAppBar
          ? AppBar(title: const Text('Productos y precios'))
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Solo el modo "todas las sucursales" necesita la lista.
        stream: sucursalId == null
            ? FirebaseFirestore.instance.collection('sucursales').snapshots()
            : null,
        builder: (context, sucursalesSnap) {
          final sucursales =
              (sucursalesSnap.data?.docs.map(Sucursal.fromDoc).toList() ?? [])
                ..sort((a, b) => a.nombre.compareTo(b.nombre));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _abrirFormulario(context, null),
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar producto'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    if (esAdmin) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HistorialStockScreen(
                              sucursalId: sucursalId,
                              nombresSucursal: {
                                for (final s in sucursales) s.id: s.nombre,
                              },
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.history),
                        label: const Text('Historial'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('productos')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final productos =
                        snapshot.data!.docs.map(Producto.fromDoc).toList()
                          ..sort((a, b) => a.nombre.compareTo(b.nombre));

                    if (productos.isEmpty) {
                      return const Center(
                        child: Text('Aún no hay productos cargados'),
                      );
                    }

                    return ListView.builder(
                      itemCount: productos.length,
                      itemBuilder: (context, indice) => _FilaProducto(
                        producto: productos[indice],
                        sucursalId: sucursalId,
                        sucursales: sucursales,
                        esAdmin: esAdmin,
                        onEditar: () =>
                            _abrirFormulario(context, productos[indice]),
                        onAgregarStock: () =>
                            _abrirAjusteStock(context, productos[indice]),
                        onEliminar: () =>
                            _confirmarEliminar(context, productos[indice]),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abrirFormulario(BuildContext context, Producto? producto) {
    showDialog(
      context: context,
      builder: (context) => _FormularioProducto(
        sucursalId: sucursalId,
        usuarioNombre: usuarioNombre,
        producto: producto,
      ),
    );
  }

  void _abrirAjusteStock(BuildContext context, Producto producto) {
    showDialog(
      context: context,
      builder: (context) => DialogoAjusteStock(
        sucursalId: sucursalId!,
        usuarioNombre: usuarioNombre,
        producto: producto,
      ),
    );
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    Producto producto,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Eliminar "${producto.nombre}"? Esta acción no se puede deshacer '
          'y lo quita de todas las sucursales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await FirebaseFirestore.instance
          .collection('productos')
          .doc(producto.id)
          .delete();
    }
  }
}

class _FilaProducto extends StatelessWidget {
  final Producto producto;
  final String? sucursalId;
  final List<Sucursal> sucursales;
  final bool esAdmin;
  final VoidCallback onEditar;
  final VoidCallback onAgregarStock;
  final VoidCallback onEliminar;

  const _FilaProducto({
    required this.producto,
    required this.sucursalId,
    required this.sucursales,
    required this.esAdmin,
    required this.onEditar,
    required this.onAgregarStock,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final detalle =
        '${formatearPesos(producto.precio)} · '
        'Código: ${producto.codigoBarras}'
        '${producto.tienePromo ? ' · Promo: ${producto.promoCantidad} x ${formatearPesos(producto.promoPrecioPack)}' : ''}';

    return ListTile(
      title: Text(producto.nombre),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detalle),
          if (!producto.controlaStock)
            const Text('Sin control de stock')
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (sucursalId == null)
                    for (final s in sucursales)
                      _ChipStock(
                        nombre: s.nombre,
                        stock: producto.stockEn(s.id),
                      )
                  else
                    _ChipStock(
                      nombre: 'Esta sucursal',
                      stock: producto.stockEn(sucursalId!),
                    ),
                ],
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(esAdmin ? Icons.edit_outlined : Icons.add_box_outlined),
            tooltip: esAdmin ? 'Editar producto' : 'Agregar stock',
            onPressed: esAdmin
                ? onEditar
                : producto.controlaStock
                ? onAgregarStock
                : null,
          ),
          if (esAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onEliminar,
            ),
        ],
      ),
    );
  }
}

/// Stock de una sucursal en una pastilla: rojo sin stock, ámbar si queda poco.
class _ChipStock extends StatelessWidget {
  final String nombre;
  final int stock;

  const _ChipStock({required this.nombre, required this.stock});

  @override
  Widget build(BuildContext context) {
    final color = stock <= 0
        ? Marca.peligro
        : stock <= 5
        ? Marca.alerta
        : Marca.textoSobreOscuro;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$nombre: $stock',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _FormularioProducto extends StatefulWidget {
  /// Con sucursal (punto de venta): se edita el stock de esa sucursal. Sin
  /// ella (catálogo del admin): no se toca el stock, que se carga desde el
  /// panel vendedor de cada sucursal.
  final String? sucursalId;
  final String usuarioNombre;
  final Producto? producto;

  const _FormularioProducto({
    required this.sucursalId,
    required this.usuarioNombre,
    this.producto,
  });

  @override
  State<_FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<_FormularioProducto> {
  final _codigoFocus = FocusNode();
  final _nombreFocus = FocusNode();
  late final _nombreController = TextEditingController(
    text: widget.producto?.nombre,
  );
  late final _codigoController = TextEditingController(
    text: widget.producto?.codigoBarras,
  );
  late final _precioController = TextEditingController(
    text: widget.producto == null ? '' : '${widget.producto!.precio}',
  );
  late final _promoCantidadController = TextEditingController(
    text: widget.producto == null || widget.producto!.promoCantidad == 0
        ? ''
        : '${widget.producto!.promoCantidad}',
  );
  late final _promoPrecioController = TextEditingController(
    text: widget.producto == null || widget.producto!.promoPrecioPack == 0
        ? ''
        : formatearPesos(
            widget.producto!.promoPrecioPack,
          ).replaceFirst('\$', ''),
  );
  // Solo hay campo de stock cuando se edita desde una sucursal.
  late final Map<String, TextEditingController> _stockControllers = {
    for (final id in _idsStock)
      id: TextEditingController(
        text: widget.producto == null ? '' : '${widget.producto!.stockEn(id)}',
      ),
  };
  late bool _controlaStock = widget.producto?.controlaStock ?? true;
  bool _guardando = false;

  List<String> get _idsStock =>
      widget.sucursalId != null ? [widget.sucursalId!] : const [];

  @override
  void dispose() {
    _codigoFocus.dispose();
    _nombreFocus.dispose();
    _nombreController.dispose();
    _codigoController.dispose();
    _precioController.dispose();
    _promoCantidadController.dispose();
    _promoPrecioController.dispose();
    for (final c in _stockControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final codigoBarras = _codigoController.text.trim();
    final precio = int.tryParse(_precioController.text) ?? 0;

    if (nombre.isEmpty || codigoBarras.isEmpty || precio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre, código de barras y precio son obligatorios'),
        ),
      );
      return;
    }

    final promoCantidad = int.tryParse(_promoCantidadController.text) ?? 0;
    final promoPrecioPack = desformatearPesos(_promoPrecioController.text);
    final tieneAlgunCampoPromo = promoCantidad > 0 || promoPrecioPack > 0;
    final promoValida =
        promoCantidad > 0 &&
        promoPrecioPack > 0 &&
        promoPrecioPack < promoCantidad * precio;

    if (tieneAlgunCampoPromo && !promoValida) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Promo inválida: el precio del pack debe ser menor que comprar '
            'esa cantidad por separado (ej: 3 x \$1.000). '
            'Deja ambos campos vacíos si no hay promo.',
          ),
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final coleccion = FirebaseFirestore.instance.collection('productos');

      // Dos productos con el mismo código harían que el escáner devuelva
      // siempre el primero que encuentre. Al editar se ignora el propio.
      final conMismoCodigo = await coleccion
          .where('codigoBarras', isEqualTo: codigoBarras)
          .get();
      final repetido = conMismoCodigo.docs
          .where((doc) => doc.id != widget.producto?.id)
          .firstOrNull;
      if (repetido != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ese código de barras ya pertenece a '
                '"${repetido.data()['nombre']}".',
              ),
            ),
          );
        }
        return;
      }

      final datosBase = {
        'nombre': nombre,
        'codigoBarras': codigoBarras,
        'precio': precio,
        'promoCantidad': promoCantidad,
        'promoPrecioPack': promoPrecioPack,
        'controlaStock': _controlaStock,
      };

      // Stock que se escribió en cada campo.
      final ingresado = {
        for (final e in _stockControllers.entries)
          e.key: int.tryParse(e.value.text) ?? 0,
      };

      final batch = FirebaseFirestore.instance.batch();
      if (widget.producto == null) {
        final ref = coleccion.doc();
        batch.set(ref, {
          ...datosBase,
          'stockPorSucursal': _controlaStock ? ingresado : {},
        });
        if (_controlaStock) {
          for (final e in ingresado.entries.where((e) => e.value > 0)) {
            registrarMovimientoStock(
              batch,
              productoId: ref.id,
              productoNombre: nombre,
              sucursalId: e.key,
              tipo: TipoMovimientoStock.stockInicial,
              cantidad: e.value,
              stockAnterior: 0,
              usuarioNombre: widget.usuarioNombre,
            );
          }
        }
      } else {
        // Solo se escribe el stock de las sucursales que cambiaron: así una
        // venta que ocurra mientras se edita no se pisa en las demás.
        final cambios = _controlaStock
            ? {
                for (final e in ingresado.entries)
                  if (e.value != widget.producto!.stockEn(e.key))
                    e.key: e.value,
              }
            : <String, int>{};
        batch.update(coleccion.doc(widget.producto!.id), {
          ...datosBase,
          for (final e in cambios.entries) 'stockPorSucursal.${e.key}': e.value,
        });
        for (final e in cambios.entries) {
          final stockAnterior = widget.producto!.stockEn(e.key);
          registrarMovimientoStock(
            batch,
            productoId: widget.producto!.id,
            productoNombre: nombre,
            sucursalId: e.key,
            tipo: TipoMovimientoStock.ajuste,
            cantidad: e.value - stockAnterior,
            stockAnterior: stockAnterior,
            usuarioNombre: widget.usuarioNombre,
          );
        }
      }
      await esperarConfirmacion(batch.commit());

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.producto == null ? 'Nuevo producto' : 'Editar producto',
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _codigoController,
                focusNode: _codigoFocus,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Código de barras',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code_scanner),
                ),
                onSubmitted: (_) => _nombreFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nombreController,
                focusNode: _nombreFocus,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _precioController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promoCantidadController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Promo: cada',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _promoPrecioController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [InputFormatoMiles()],
                      decoration: const InputDecoration(
                        labelText: 'Por',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Déjalos vacíos si no hay promo. Ej: cada 3 por \$1.000 → '
                  'ese pack de 3 cuesta \$1.000 en total, sin importar el '
                  'precio unitario.',
                  style: TextStyle(fontSize: 12, color: Marca.textoSuave),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Controla stock'),
                value: _controlaStock,
                onChanged: (valor) => setState(() => _controlaStock = valor),
              ),
              if (_controlaStock && _stockControllers.isEmpty)
                const Text(
                  'El stock de cada sucursal se carga desde el panel '
                  'vendedor.',
                  style: TextStyle(fontSize: 12, color: Marca.textoSuave),
                ),
              if (_controlaStock)
                for (final e in _stockControllers.values) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: e,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Stock en esta sucursal',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
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
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
