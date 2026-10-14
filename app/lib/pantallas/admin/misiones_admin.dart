import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/mision.dart' show DificultadX;
import '../../modelos/mision_admin.dart';
import '../../sesion/sesion.dart';
import 'mision_admin.dart';

/// Listado de misiones para administrar.
///
/// En el panel web cada fila tenía los botones al costado. En un teléfono no
/// entran y se toca el equivocado, así que la tarjeta entera abre la misión y
/// las acciones viven adentro.
class PantallaMisionesAdmin extends StatefulWidget {
  const PantallaMisionesAdmin({super.key});

  @override
  State<PantallaMisionesAdmin> createState() => _PantallaMisionesAdminState();
}

class _PantallaMisionesAdminState extends State<PantallaMisionesAdmin> {
  Future<List<MisionAdmin>>? _misiones;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _misiones ??= _pedir();
  }

  Future<List<MisionAdmin>> _pedir() {
    final pedido = listarMisiones(ProveedorSesion.de(context).token!);
    pedido.ignore();
    return pedido;
  }

  Future<void> _recargar() async {
    final pedido = _pedir();
    // Con llaves y no con flecha: la flecha devolveria el Future asignado y
    // setState lo rechaza, dejando la pantalla sin redibujar.
    setState(() {
      _misiones = pedido;
    });
    await pedido.then((_) {}, onError: (_, __) {});
  }

  Future<void> _abrir({int? id, String? nombre}) async {
    final huboCambios = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaMisionAdmin(misionId: id, nombreConocido: nombre),
      ),
    );
    if (huboCambios == true) await _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ProveedorSesion.de(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: Row(
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Misiones', style: AppText.serif(size: 24)),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 18,
                    width: double.infinity,
                    child: CustomPaint(painter: GrecaPainter()),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<MisionAdmin>>(
                future: _misiones,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.acento),
                    );
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    if (error is ErrorApi && error.sesionVencida) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        sesion.cerrarSesion();
                        Navigator.of(context).pop();
                      });
                    }
                    return _Centrado(
                      texto: error is ErrorApi ? error.mensaje : 'Ocurrió un problema inesperado.',
                      alReintentar: _recargar,
                    );
                  }

                  final misiones = snapshot.data ?? const <MisionAdmin>[];
                  if (misiones.isEmpty) {
                    return _Centrado(
                      texto: 'Todavía no hay misiones cargadas.',
                      alReintentar: _recargar,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _recargar,
                    color: AppColors.acento,
                    backgroundColor: AppColors.superficie,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: misiones.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _Tarjeta(
                        mision: misiones[i],
                        alTocar: () => _abrir(id: misiones[i].id, nombre: misiones[i].nombre),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(),
        backgroundColor: AppColors.acento,
        foregroundColor: AppColors.fondo,
        icon: const Icon(Icons.add),
        label: Text('Nueva misión', style: AppText.sans(size: 14, color: AppColors.fondo, peso: FontWeight.w700)),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final MisionAdmin mision;
  final VoidCallback alTocar;

  const _Tarjeta({required this.mision, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mision.nombre,
                    style: AppText.serif(size: 17),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                _Estado(activa: mision.activa),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${mision.duracionMin} min', style: AppText.sans(size: 12.5)),
                const SizedBox(width: 14),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: mision.dificultad.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(mision.dificultad.etiqueta, style: AppText.sans(size: 12.5)),
                const Spacer(),
                Text(
                  mision.desafios == 0
                      ? 'sin desafíos'
                      : '${mision.desafios} ${mision.desafios == 1 ? 'desafío' : 'desafíos'}',
                  style: AppText.sans(
                    size: 12.5,
                    color: mision.desafios == 0 ? AppColors.textoInactivo : AppColors.textoSecundario,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Estado extends StatelessWidget {
  final bool activa;
  const _Estado({required this.activa});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activa ? AppColors.facil : AppColors.borde),
      ),
      child: Text(
        activa ? 'Publicada' : 'Borrador',
        style: AppText.sans(
          size: 11.5,
          color: activa ? AppColors.facil : AppColors.textoSecundario,
          peso: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Centrado extends StatelessWidget {
  final String texto;
  final Future<void> Function() alReintentar;

  const _Centrado({required this.texto, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(texto, textAlign: TextAlign.center, style: AppText.sans(size: 14)),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: alReintentar,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.acento,
                side: const BorderSide(color: AppColors.acento),
              ),
              child: Text(
                'Reintentar',
                style: AppText.sans(size: 14, color: AppColors.acento, peso: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
