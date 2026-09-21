import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../admin/clientes_screen.dart';
import '../admin/home_admin.dart';
import '../admin/productos_screen.dart';
import '../users/home_vendedor.dart';
import 'cierre_turno_screen.dart';
import 'venta_screen.dart';
import '../theme/marca.dart';

enum _SalidaAdmin { cancelar, irACerrar, salir }

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

  /// Solo el admin puede salir del punto de venta sin cerrar el turno para
  /// volver a su panel. Como no hay forma de retomar un turno abierto, se le
  /// avisa y se le ofrece cerrarlo en vez de salir.
  Future<void> _volverAlPanel() async {
    final decision = await showDialog<_SalidaAdmin>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Volver al panel de admin'),
        content: const Text(
          'El turno sigue abierto y no se puede retomar desde el panel. '
          'Si ya terminaste de vender, ciérralo antes de salir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _SalidaAdmin.cancelar),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _SalidaAdmin.irACerrar),
            child: const Text('Cerrar turno'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _SalidaAdmin.salir),
            child: const Text('Salir sin cerrar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (decision) {
      case _SalidaAdmin.salir:
        Navigator.of(context).pop();
      case _SalidaAdmin.irACerrar:
        setState(() => _seleccionado = 3);
      case _SalidaAdmin.cancelar || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (volvio, _) {
        if (!volvio && widget.esAdmin) _volverAlPanel();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: widget.esAdmin
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Volver al panel de admin',
                  onPressed: _volverAlPanel,
                )
              : null,
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
                    esAdmin: widget.esAdmin,
                    mostrarAppBar: false,
                  ),
                  ProductosScreen(
                    sucursalId: widget.sucursalId,
                    usuarioNombre: widget.vendedorNombre,
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
    return SizedBox(
      height: 92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: seleccionado
              ? Marca.degradadoDorado
              : Marca.degradadoTarjeta,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: seleccionado ? Marca.doradoClaro : Marca.borde,
          ),
          boxShadow: seleccionado ? Marca.brilloDorado : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icono,
                  size: 30,
                  color: seleccionado ? Marca.negro : Marca.dorado,
                ),
                const SizedBox(height: 8),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: seleccionado
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: seleccionado ? Marca.negro : Marca.texto,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
