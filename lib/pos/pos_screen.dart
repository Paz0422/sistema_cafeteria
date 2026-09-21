import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../admin/clientes_screen.dart';
import '../admin/home_admin.dart';
import '../admin/productos_screen.dart';
import '../users/home_vendedor.dart';
import 'cierre_turno_screen.dart';
import 'venta_screen.dart';

class PosScreen extends StatefulWidget {
  final String turnoId;
  final String sucursalId;
  final String grupoClientesId;
  final String vendedorNombre;
  final int montoInicial;
  final bool esAdmin;

  const PosScreen({
    super.key,
    required this.turnoId,
    required this.sucursalId,
    required this.grupoClientesId,
    required this.vendedorNombre,
    required this.montoInicial,
    this.esAdmin = false,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  int _seleccionado = 0;

  Future<void> _cerrarSesion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Tu turno sigue abierto y cualquier carrito sin cobrar se '
          'perderá. ¿Cerrar sesión igual?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Punto de venta'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: _cerrarSesion,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _AccionGrande(
                      icono: Icons.point_of_sale,
                      etiqueta: 'Realizar venta',
                      seleccionado: _seleccionado == 0,
                      onTap: () => setState(() => _seleccionado = 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AccionGrande(
                      icono: Icons.inventory_2_outlined,
                      etiqueta: 'Productos',
                      seleccionado: _seleccionado == 1,
                      onTap: () => setState(() => _seleccionado = 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AccionGrande(
                      icono: Icons.assignment_ind_outlined,
                      etiqueta: 'Clientes',
                      seleccionado: _seleccionado == 2,
                      onTap: () => setState(() => _seleccionado = 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AccionGrande(
                      icono: Icons.lock_clock,
                      etiqueta: 'Cerrar turno',
                      seleccionado: _seleccionado == 3,
                      onTap: () => setState(() => _seleccionado = 3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: IndexedStack(
                index: _seleccionado,
                children: [
                  VentaScreen(
                    turnoId: widget.turnoId,
                    sucursalId: widget.sucursalId,
                    grupoClientesId: widget.grupoClientesId,
                    vendedorNombre: widget.vendedorNombre,
                    montoInicial: widget.montoInicial,
                    mostrarAppBar: false,
                  ),
                  ProductosScreen(
                    sucursalId: widget.sucursalId,
                    esAdmin: widget.esAdmin,
                    mostrarAppBar: false,
                  ),
                  ClientesScreen(
                    grupoClientesId: widget.grupoClientesId,
                    esAdmin: widget.esAdmin,
                    mostrarAppBar: false,
                  ),
                  CierreTurnoScreen(
                    turnoId: widget.turnoId,
                    vendedorNombre: widget.vendedorNombre,
                    montoInicial: widget.montoInicial,
                    mostrarAppBar: false,
                    alCerrar: () => widget.esAdmin
                        ? HomeAdmin(nombre: widget.vendedorNombre)
                        : HomeVendedor(nombre: widget.vendedorNombre),
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

class _AccionGrande extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final bool seleccionado;
  final VoidCallback onTap;

  const _AccionGrande({
    required this.icono,
    required this.etiqueta,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorPrimario = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 92,
      child: Card(
        elevation: seleccionado ? 4 : 1,
        color: seleccionado ? colorPrimario.withValues(alpha: 0.12) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: seleccionado ? colorPrimario : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 32, color: seleccionado ? colorPrimario : null),
              const SizedBox(height: 8),
              Text(
                etiqueta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: seleccionado
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: seleccionado ? colorPrimario : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
