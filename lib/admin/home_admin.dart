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

class HomeAdmin extends StatefulWidget {
  final String nombre;

  const HomeAdmin({super.key, required this.nombre});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cafetería Fusión — Admin: ${widget.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _indice,
            onDestinationSelected: (indice) => setState(() => _indice = indice),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('Estadísticas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale),
                label: Text('Panel vendedor'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Productos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_ind_outlined),
                selectedIcon: Icon(Icons.assignment_ind),
                label: Text('Clientes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Usuarios'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: Text('Sucursales'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
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
            ),
          ),
        ],
      ),
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
