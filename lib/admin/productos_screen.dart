import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producto.dart';
import '../utils/formato.dart';

class ProductosScreen extends StatelessWidget {
  final bool esAdmin;
  final bool mostrarAppBar;

  const ProductosScreen({
    super.key,
    this.esAdmin = false,
    this.mostrarAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mostrarAppBar
          ? AppBar(title: const Text('Productos y precios'))
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _abrirFormulario(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Agregar producto'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('productos')
                  .orderBy('nombre')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final productos = snapshot.data!.docs
                    .map(Producto.fromDoc)
                    .toList();

                if (productos.isEmpty) {
                  return const Center(
                    child: Text('Aún no hay productos cargados'),
                  );
                }

                return ListView.builder(
                  itemCount: productos.length,
                  itemBuilder: (context, indice) {
                    final producto = productos[indice];
                    return ListTile(
                      title: Text(producto.nombre),
                      subtitle: Text(
                        '${formatearPesos(producto.precio)} · '
                        'Código: ${producto.codigoBarras}'
                        '${producto.tienePromo ? ' · Promo: ${producto.promoCantidad} x ${formatearPesos(producto.promoPrecioPack)}' : ''}'
                        '${producto.controlaStock ? ' · Stock: ${producto.stock}' : ' · Sin control de stock'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              esAdmin
                                  ? Icons.edit_outlined
                                  : Icons.add_box_outlined,
                            ),
                            tooltip: esAdmin
                                ? 'Editar producto'
                                : 'Agregar stock',
                            onPressed: esAdmin
                                ? () => _abrirFormulario(context, producto)
                                : producto.controlaStock
                                ? () => _abrirAjusteStock(context, producto)
                                : null,
                          ),
                          if (esAdmin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _confirmarEliminar(context, producto),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _abrirFormulario(BuildContext context, Producto? producto) {
    showDialog(
      context: context,
      builder: (context) => _FormularioProducto(producto: producto),
    );
  }

  void _abrirAjusteStock(BuildContext context, Producto producto) {
    showDialog(
      context: context,
      builder: (context) => _DialogoAjusteStock(producto: producto),
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
          '¿Eliminar "${producto.nombre}"? Esta acción no se puede deshacer.',
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

class _FormularioProducto extends StatefulWidget {
  final Producto? producto;

  const _FormularioProducto({this.producto});

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
  late final _stockController = TextEditingController(
    text: widget.producto == null ? '' : '${widget.producto!.stock}',
  );
  late bool _controlaStock = widget.producto?.controlaStock ?? true;
  bool _guardando = false;

  @override
  void dispose() {
    _codigoFocus.dispose();
    _nombreFocus.dispose();
    _nombreController.dispose();
    _codigoController.dispose();
    _precioController.dispose();
    _promoCantidadController.dispose();
    _promoPrecioController.dispose();
    _stockController.dispose();
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
      final datos = {
        'nombre': nombre,
        'codigoBarras': codigoBarras,
        'precio': precio,
        'promoCantidad': promoCantidad,
        'promoPrecioPack': promoPrecioPack,
        'controlaStock': _controlaStock,
        'stock': _controlaStock
            ? (int.tryParse(_stockController.text) ?? 0)
            : 0,
      };

      final coleccion = FirebaseFirestore.instance.collection('productos');
      if (widget.producto == null) {
        await coleccion.add(datos);
      } else {
        await coleccion.doc(widget.producto!.id).update(datos);
      }

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
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Controla stock'),
                value: _controlaStock,
                onChanged: (valor) => setState(() => _controlaStock = valor),
              ),
              if (_controlaStock)
                TextField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Stock disponible',
                    border: OutlineInputBorder(),
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

class _DialogoAjusteStock extends StatefulWidget {
  final Producto producto;

  const _DialogoAjusteStock({required this.producto});

  @override
  State<_DialogoAjusteStock> createState() => _DialogoAjusteStockState();
}

class _DialogoAjusteStockState extends State<_DialogoAjusteStock> {
  final _cantidadController = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final cantidadAgregar = int.tryParse(_cantidadController.text);
    if (cantidadAgregar == null || cantidadAgregar <= 0) return;

    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('productos')
          .doc(widget.producto.id)
          .update({'stock': widget.producto.stock + cantidadAgregar});

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Agregar stock: ${widget.producto.nombre}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stock actual: ${widget.producto.stock}'),
          const SizedBox(height: 12),
          TextField(
            controller: _cantidadController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Cantidad que llegó',
              border: OutlineInputBorder(),
              prefixText: '+ ',
            ),
          ),
        ],
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
