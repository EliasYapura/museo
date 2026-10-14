import 'package:flutter/material.dart';

import '../../api/cliente.dart';
import '../../estilo.dart';
import '../../modelos/desafio.dart';
import '../../sesion/sesion.dart';
import '../../widgets/formulario.dart';
import 'formulario_desafio.dart';

/// Crear un desafío para una misión o editar uno existente.
///
/// Con [desafio] en null es un alta. Al volver devuelve true si hubo cambios,
/// para que el listado se actualice solo.
///
/// Para editar no se vuelve a pedir el desafío: el listado ya trae todo lo que
/// el formulario necesita, así que la pantalla abre al instante con lo que ya
/// estaba a la vista.
class PantallaDesafioAdmin extends StatefulWidget {
  final int misionId;
  final Desafio? desafio;

  /// Qué lugar ocupa en la misión, para el título. Es la posición en el
  /// listado y no la columna orden: al borrar uno, la base deja el hueco.
  final int? posicion;

  const PantallaDesafioAdmin({
    super.key,
    required this.misionId,
    this.desafio,
    this.posicion,
  });

  @override
  State<PantallaDesafioAdmin> createState() => _PantallaDesafioAdminState();
}

class _PantallaDesafioAdminState extends State<PantallaDesafioAdmin> {
  /// Se marca al guardar, para avisarle al listado que tiene que recargar.
  bool _huboCambios = false;

  bool _borrando = false;
  String _error = '';

  bool get _esAlta => widget.desafio == null;

  Future<String?> _guardar(Map<String, dynamic> datos) async {
    final sesion = ProveedorSesion.de(context);

    if (_esAlta) {
      await crearDesafio(sesion.token!, widget.misionId, datos);
      _huboCambios = true;
      if (!mounted) return null;
      // Tras crearlo no tiene sentido quedarse en un formulario lleno: se
      // vuelve al listado, donde el desafío nuevo ya aparece al final.
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Desafío agregado al final de la misión.')),
      );
      return null;
    }

    await editarDesafio(sesion.token!, widget.desafio!.id, datos);
    _huboCambios = true;
    // A diferencia de las misiones, la API de desafíos no avisa si hubo
    // cambios de verdad, así que el aviso no puede distinguirlo.
    return 'Cambios guardados.';
  }

  /// Borra el desafío, después de confirmar, y vuelve al listado.
  Future<void> _borrar() async {
    final sesion = ProveedorSesion.de(context);
    final confirmado = await _confirmarBorrado();
    if (confirmado != true || !mounted) return;

    setState(() {
      _borrando = true;
      _error = '';
    });
    try {
      final despublicada = await borrarDesafio(sesion.token!, widget.desafio!.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // Quedarse sin desafíos despublica la misión. Es un cambio que no
            // se pidió y que pasa en otra pantalla, así que se avisa acá.
            despublicada
                ? 'Desafío borrado. La misión volvió a borrador porque se quedó sin desafíos.'
                : 'Desafío borrado.',
          ),
        ),
      );
    } on ErrorApi catch (error) {
      if (!mounted) return;
      if (error.sesionVencida) {
        sesion.cerrarSesion();
        Navigator.of(context).pop(_huboCambios);
        return;
      }
      setState(() => _error = error.mensaje);
    } catch (error, pila) {
      debugPrint('Fallo al borrar el desafío: $error\n$pila');
      if (mounted) setState(() => _error = 'No se pudo borrar el desafío.');
    } finally {
      if (mounted) setState(() => _borrando = false);
    }
  }

  /// Borrar un desafío no se deshace, así que se pregunta antes.
  Future<bool?> _confirmarBorrado() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.superficie,
        title: Text('¿Borrar el desafío?', style: AppText.serif(size: 19)),
        content: Text(
          'Se borra de la misión y no se puede deshacer. Los demás quedan en el '
          'mismo orden.\n\n'
          'Si era el único, la misión vuelve a borrador: una misión sin desafíos '
          'no se puede publicar.',
          style: AppText.sans(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: AppText.sans(size: 14, peso: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sí, borrar',
              style: AppText.sans(size: 14, color: AppColors.dificil, peso: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        'Desafíos',
                        style: AppText.sans(size: 13).copyWith(letterSpacing: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: [
                    Text(
                      _esAlta ? 'Nuevo desafío' : 'Desafío ${widget.posicion ?? ''}'.trim(),
                      style: AppText.serif(size: 24),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 18,
                      width: double.infinity,
                      child: CustomPaint(painter: GrecaPainter()),
                    ),
                    const SizedBox(height: 20),
                    FormularioDesafio(
                      desafio: widget.desafio,
                      alGuardar: _guardar,
                      textoBoton: _esAlta ? 'Agregar desafío' : 'Guardar cambios',
                    ),
                    // Borrar va aparte del formulario y sólo al editar: en el
                    // alta no hay nada que borrar todavía.
                    if (!_esAlta) ...[
                      const SizedBox(height: 26),
                      if (_error.isNotEmpty) ...[
                        Aviso(_error),
                        const SizedBox(height: 12),
                      ],
                      const Divider(color: AppColors.borde, height: 1),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _borrando ? null : _borrar,
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: _borrando ? AppColors.textoInactivo : AppColors.dificil,
                          ),
                          label: Text(
                            _borrando ? 'Borrando…' : 'Borrar desafío',
                            style: AppText.sans(
                              size: 13.5,
                              color: _borrando ? AppColors.textoInactivo : AppColors.dificil,
                              peso: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
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
