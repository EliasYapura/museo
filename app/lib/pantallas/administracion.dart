import 'package:flutter/material.dart';

import '../api/cliente.dart';
import '../estilo.dart';
import '../sesion/sesion.dart';

/// Portada de administración: lo primero que ve el equipo del museo al entrar.
///
/// Por ahora resume cuánto contenido hay cargado. Las pantallas de misiones,
/// desafíos y objetos se van sumando acá a medida que se trasladan del panel.
class PantallaAdministracion extends StatefulWidget {
  const PantallaAdministracion({super.key});

  @override
  State<PantallaAdministracion> createState() => _PantallaAdministracionState();
}

class _PantallaAdministracionState extends State<PantallaAdministracion> {
  Future<({int misiones, int publicadas, int objetos})>? _resumen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resumen ??= _pedir();
  }

  Future<({int misiones, int publicadas, int objetos})> _pedir() {
    final pedido = obtenerResumen(ProveedorSesion.de(context).token!);
    pedido.ignore();
    return pedido;
  }

  Future<void> _recargar() async {
    final pedido = _pedir();
    setState(() {
      _resumen = pedido;
    });
    await pedido.then((_) {}, onError: (_, __) {});
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ProveedorSesion.de(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: AppColors.textoPrimario,
                  tooltip: 'Volver',
                ),
                Expanded(
                  child: Text(
                    'Administración',
                    style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
                  ),
                ),
                IconButton(
                  onPressed: _recargar,
                  icon: const Icon(Icons.refresh),
                  color: AppColors.acento,
                  tooltip: 'Actualizar',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Contenido del museo', style: AppText.serif(size: 24)),
            const SizedBox(height: 14),
            SizedBox(
              height: 18,
              width: double.infinity,
              child: CustomPaint(painter: GrecaPainter()),
            ),
            const SizedBox(height: 20),

            FutureBuilder<({int misiones, int publicadas, int objetos})>(
              future: _resumen,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.acento)),
                  );
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  // Un token vencido no se arregla reintentando: hay que
                  // volver a entrar.
                  if (error is ErrorApi && error.sesionVencida) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      sesion.cerrarSesion();
                      Navigator.of(context).pop();
                    });
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        Text(
                          error is ErrorApi ? error.mensaje : 'Ocurrió un problema inesperado.',
                          textAlign: TextAlign.center,
                          style: AppText.sans(size: 14),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton(
                          onPressed: _recargar,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.acento,
                            side: const BorderSide(color: AppColors.acento),
                          ),
                          child: Text(
                            'Reintentar',
                            style: AppText.sans(
                              size: 14,
                              color: AppColors.acento,
                              peso: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final datos = snapshot.data!;
                return Column(
                  children: [
                    _Tarjeta(
                      numero: '${datos.misiones}',
                      titulo: datos.misiones == 1 ? 'misión cargada' : 'misiones cargadas',
                      detalle: '${datos.publicadas} publicadas',
                    ),
                    const SizedBox(height: 12),
                    _Tarjeta(
                      numero: '${datos.objetos}',
                      titulo: datos.objetos == 1 ? 'objeto registrado' : 'objetos registrados',
                      detalle: 'piezas del museo con su código',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final String numero;
  final String titulo;
  final String detalle;

  const _Tarjeta({required this.numero, required this.titulo, required this.detalle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(numero, style: AppText.serif(size: 32, color: AppColors.acento)),
          const SizedBox(height: 2),
          Text(titulo, style: AppText.sans(size: 15, color: AppColors.textoPrimario)),
          const SizedBox(height: 4),
          Text(detalle, style: AppText.sans(size: 13)),
        ],
      ),
    );
  }
}
