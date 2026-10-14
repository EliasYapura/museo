import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/mision_admin.dart';
import '../../sesion/sesion.dart';
import 'formulario_mision.dart';

/// Crear una misión o editar una existente.
///
/// Con [misionId] en null es un alta. Al volver devuelve true si hubo cambios,
/// para que el listado se actualice solo.
class PantallaMisionAdmin extends StatefulWidget {
  final int? misionId;
  final String? nombreConocido;

  const PantallaMisionAdmin({super.key, this.misionId, this.nombreConocido});

  @override
  State<PantallaMisionAdmin> createState() => _PantallaMisionAdminState();
}

class _PantallaMisionAdminState extends State<PantallaMisionAdmin> {
  Future<MisionAdmin?>? _mision;

  /// Se marca al guardar, para avisarle al listado que tiene que recargar.
  bool _huboCambios = false;

  /// El nombre del título, que cambia si se lo edita y se guarda.
  String? _nombreMostrado;

  bool get _esAlta => widget.misionId == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mision ??= _pedir();
  }

  Future<MisionAdmin?> _pedir() {
    if (_esAlta) return Future.value(null);
    final pedido = obtenerMisionAdmin(ProveedorSesion.de(context).token!, widget.misionId!);
    pedido.ignore();
    return pedido;
  }

  Future<void> _recargar() async {
    final pedido = _pedir();
    // Con llaves y no con flecha: la flecha devolveria el Future asignado y
    // setState lo rechaza, dejando la pantalla sin redibujar.
    setState(() {
      _mision = pedido;
    });
    await pedido.then((_) {}, onError: (_, __) {});
  }

  Future<String?> _guardar(Map<String, dynamic> datos) async {
    final sesion = ProveedorSesion.de(context);

    if (_esAlta) {
      final creada = await crearMision(sesion.token!, datos);
      _huboCambios = true;
      if (!mounted) return null;
      // Tras crearla no tiene sentido quedarse en un formulario vacío: se
      // vuelve al listado, donde la misión nueva ya aparece.
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Misión “${creada.nombre}” creada como borrador.')),
      );
      return null;
    }

    final resultado = await editarMision(sesion.token!, widget.misionId!, datos);
    _huboCambios = _huboCambios || resultado.modificada;
    // No se reemplaza el future de la misión: hacerlo manda al FutureBuilder
    // de vuelta a "cargando" por un cuadro, y en ese instante el formulario se
    // destruye y se vuelve a crear, perdiendo el aviso de que se guardó.
    // Alcanza con actualizar el título, que es lo único de esta pantalla que
    // no vive dentro del formulario.
    if (mounted) {
      setState(() {
        _nombreMostrado = resultado.mision.nombre;
      });
    }
    return resultado.modificada ? 'Cambios guardados.' : 'No había cambios para guardar.';
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ProveedorSesion.de(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (seFue, _) {
        if (!seFue) Navigator.of(context).pop(_huboCambios);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(_huboCambios),
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.textoPrimario,
                      tooltip: 'Volver',
                    ),
                    Expanded(
                      child: Text(
                        _esAlta ? 'Nueva misión' : 'Editar misión',
                        style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<MisionAdmin?>(
                  future: _mision,
                  builder: (context, snapshot) {
                    if (!_esAlta && snapshot.connectionState == ConnectionState.waiting) {
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
                          Navigator.of(context).pop(false);
                        });
                      }
                      return _ErrorCargando(
                        mensaje: error is ErrorApi
                            ? error.mensaje
                            : 'Ocurrió un problema inesperado.',
                        alReintentar: _recargar,
                      );
                    }

                    final mision = snapshot.data;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      children: [
                        Text(
                          _nombreMostrado ?? mision?.nombre ?? widget.nombreConocido ?? 'Nueva misión',
                          style: AppText.serif(size: 24),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 18,
                          width: double.infinity,
                          child: CustomPaint(painter: GrecaPainter()),
                        ),
                        const SizedBox(height: 20),
                        FormularioMision(
                          // La key fuerza a rearmar el formulario cuando la
                          // misión se recarga, para que los campos muestren lo
                          // último guardado.
                          key: ValueKey(mision?.id),
                          mision: mision,
                          alGuardar: _guardar,
                          textoBoton: _esAlta ? 'Crear misión' : 'Guardar cambios',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCargando extends StatelessWidget {
  final String mensaje;
  final Future<void> Function() alReintentar;

  const _ErrorCargando({required this.mensaje, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(mensaje, textAlign: TextAlign.center, style: AppText.sans(size: 14)),
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
