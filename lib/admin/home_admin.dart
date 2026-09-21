import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sucursal.dart';
import '../pos/selector_sucursal_apertura.dart';
import 'clientes_screen.dart';
import 'estadisticas_screen.dart';
import 'productos_screen.dart';
import 'sucursales_screen.dart';
import 'usuarios_screen.dart';
import '../widgets/logo_fusion.dart';

class HomeAdmin extends StatefulWidget {
  final String nombre;

  const HomeAdmin({super.key, required this.nombre});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

/// Ancho bajo el cual el panel pasa a modo celular: el menú lateral se
/// esconde en un cajón y el contenido usa todo el ancho.
const _anchoCelular = 700.0;

class _Seccion {
  final String titulo;
  final IconData icono;
  final IconData iconoActivo;

  const _Seccion(this.titulo, this.icono, this.iconoActivo);
}

const _secciones = [
  _Seccion('Estadísticas', Icons.bar_chart_outlined, Icons.bar_chart),
  _Seccion('Panel vendedor', Icons.point_of_sale_outlined, Icons.point_of_sale),
  _Seccion('Productos', Icons.inventory_2_outlined, Icons.inventory_2),
  _Seccion('Clientes', Icons.assignment_ind_outlined, Icons.assignment_ind),
  _Seccion('Usuarios', Icons.people_outline, Icons.people),
  _Seccion('Sucursales', Icons.storefront_outlined, Icons.storefront),
];

class _HomeAdminState extends State<HomeAdmin> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final celular = MediaQuery.sizeOf(context).width < _anchoCelular;
    final contenido = _contenido();

    final cerrarSesion = IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Cerrar sesión',
      onPressed: () => FirebaseAuth.instance.signOut(),
    );

    if (celular) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_secciones[_indice].titulo),
          actions: [cerrarSesion],
        ),
        drawer: NavigationDrawer(
          selectedIndex: _indice,
          onDestinationSelected: (indice) => setState(() => _indice = indice),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 12),
              child: Row(
                children: [
                  const LogoFusion(tamano: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            for (final seccion in _secciones)
              NavigationDrawerDestination(
                icon: Icon(seccion.icono),
                selectedIcon: Icon(seccion.iconoActivo),
                label: Text(seccion.titulo),
              ),
          ],
        ),
        body: contenido,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Cafetería Fusión — Admin: ${widget.nombre}'),
        actions: [cerrarSesion],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _indice,
            onDestinationSelected: (indice) => setState(() => _indice = indice),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 16),
              child: LogoFusion(tamano: 56),
            ),
            destinations: [
              for (final seccion in _secciones)
                NavigationRailDestination(
                  icon: Icon(seccion.icono),
                  selectedIcon: Icon(seccion.iconoActivo),
                  label: Text(seccion.titulo),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: contenido),
        ],
      ),
    );
  }

  Widget _contenido() {
    return IndexedStack(
      index: _indice,
      children: [
        const EstadisticasScreen(mostrarAppBar: false),
        SelectorSucursalApertura(
          nombreVendedor: widget.nombre,
          esAdmin: true,
          descripcion:
              'Entra al punto de venta de una sucursal con permisos '
              'completos de administrador (puedes eliminar productos '
              'y bajar stock, cosas que un vendedor normal no puede).',
          textoBoton: 'Entrar como vendedor',
        ),
        _ConSucursalSeleccionada(
          builder: (sucursal) => ProductosScreen(
            sucursalId: sucursal.id,
            usuarioNombre: widget.nombre,
            esAdmin: true,
            mostrarAppBar: false,
          ),
        ),
        _ConSucursalSeleccionada(
          builder: (sucursal) => ClientesScreen(
            grupoClientesId: sucursal.grupoClientes,
            esAdmin: true,
            mostrarAppBar: false,
          ),
        ),
        const UsuariosScreen(mostrarAppBar: false),
        const SucursalesScreen(mostrarAppBar: false),
      ],
    );
  }
}

/// Muestra un selector de sucursal y, una vez elegida, construye [builder]
/// con esa sucursal — lo reutilizan las pestañas de Productos y Clientes,
/// que ahora son datos propios de cada sucursal.
class _ConSucursalSeleccionada extends StatefulWidget {
  final Widget Function(Sucursal sucursal) builder;

  const _ConSucursalSeleccionada({required this.builder});

  @override
  State<_ConSucursalSeleccionada> createState() =>
      _ConSucursalSeleccionadaState();
}

class _ConSucursalSeleccionadaState extends State<_ConSucursalSeleccionada> {
  String? _sucursalId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('sucursales').snapshots(),
      builder: (context, snapshot) {
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
                'Primero crea una sucursal en la sección "Sucursales".',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final sucursalId =
            (_sucursalId != null && sucursales.any((s) => s.id == _sucursalId))
            ? _sucursalId
            : sucursales.first.id;
        final sucursalSeleccionada = sucursales.firstWhere(
          (s) => s.id == sucursalId,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SizedBox(
                width: 320,
                child: DropdownButtonFormField<String>(
                  initialValue: sucursalId,
                  decoration: const InputDecoration(
                    labelText: 'Sucursal',
                    border: OutlineInputBorder(),
                    isDense: true,
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
              ),
            ),
            Expanded(child: widget.builder(sucursalSeleccionada)),
          ],
        );
      },
    );
  }
}
